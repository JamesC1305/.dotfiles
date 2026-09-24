-- Repo-local Neovim hooks for Firecracker.
--
-- Enable with `:set exrc` in your personal Neovim config, then trust this file
-- if your Neovim version prompts for local config trust.

local source = debug.getinfo(1, "S").source
local config_path = source:sub(1, 1) == "@" and source:sub(2) or ".nvim.lua"
local root = vim.fn.fnamemodify(config_path, ":p:h")
root = vim.uv.fs_realpath(root) or root
local devtool = root .. "/tools/devtool"

if vim.fn.executable(devtool) ~= 1 then
  vim.notify("Firecracker devtool not found at " .. devtool, vim.log.levels.WARN)
  return
end

local group = vim.api.nvim_create_augroup("firecracker_devtool", { clear = true })

local overseer = require("overseer")

package.preload["overseer.component.firecracker.reload"] = function()
  return {
    desc = "Reload files after a Firecracker formatter finishes",
    constructor = function()
      return {
        on_complete = function()
          vim.schedule(function()
            vim.cmd("silent! checktime")
          end)
        end,
      }
    end,
  }
end

local function task_definition(argv, reload)
  local components = { "default", { "on_output_quickfix", open_on_exit = "failure", tail = false } }
  if reload then
    table.insert(components, "firecracker.reload")
  end
  return { cmd = argv, cwd = root, components = components }
end

local function devtool_sh(command)
  return { devtool, "sh", command }
end

local function relative_to_root(path)
  local absolute = vim.fn.fnamemodify(path, ":p")
  absolute = vim.uv.fs_realpath(absolute) or absolute
  local prefix = root .. "/"

  if absolute:sub(1, #prefix) ~= prefix then
    return nil
  end

  return absolute:sub(#prefix + 1)
end

-- Capture the source buffer before Overseer opens its picker. Only the
-- current-file formatter depends on that buffer; all tasks run from root.
local registered_roots = vim.g.firecracker_overseer_registered or {}
local registration_root = vim.uv.fs_realpath(root) or root
if not registered_roots[registration_root] then
  overseer.register_template({
    name = "Firecracker workflows",
    condition = { dir = root },
    generator = function()
      local templates = {
        {
          name = "Firecracker: format all",
          aliases = { "FirecrackerFmtAll" },
          builder = function()
            vim.cmd("wall")
            return task_definition({ devtool, "fmt" }, true)
          end,
        },
        {
          name = "Firecracker: check style",
          aliases = { "FirecrackerCheckStyle" },
          builder = function()
            return task_definition({ devtool, "checkstyle" })
          end,
        },
        {
          name = "Firecracker: check build",
          aliases = { "FirecrackerCheckBuild" },
          builder = function()
            return task_definition({ devtool, "checkbuild" })
          end,
        },
      }

      local buf = vim.api.nvim_get_current_buf()
      local path = vim.api.nvim_buf_get_name(buf)
      local relative = path ~= "" and relative_to_root(path) or nil
      local filetype = vim.bo[buf].filetype
      local command
      if relative and vim.bo[buf].buftype == "" then
        local file = vim.fn.shellescape(relative)
        if filetype == "python" then
          command = "black --config tests/pyproject.toml "
            .. file
            .. " && isort --settings-path tests/pyproject.toml "
            .. file
        elseif filetype == "rust" then
          command = "cargo fmt --all"
        elseif filetype == "markdown" then
          command = "mdformat " .. file
        end
      end
      if command then
        table.insert(templates, {
          name = "Firecracker: format current file",
          aliases = { "FirecrackerFmt" },
          builder = function()
            vim.api.nvim_buf_call(buf, function()
              vim.cmd("write")
            end)
            return task_definition(devtool_sh(command), true)
          end,
        })
      end
      return templates
    end,
  })
  registered_roots[registration_root] = true
  vim.g.firecracker_overseer_registered = registered_roots
end

for command, desc in pairs({
  FirecrackerFmt = "Format the current file with Firecracker's devtool formatters",
  FirecrackerFmtAll = "Run tools/devtool fmt",
  FirecrackerCheckStyle = "Run tools/devtool checkstyle",
  FirecrackerCheckBuild = "Run tools/devtool checkbuild",
}) do
  vim.api.nvim_create_user_command(command, function()
    overseer.run_task({ name = command, search_params = { dir = root, filetype = vim.bo.filetype } }, function(_, err)
      if err then
        vim.notify(err, vim.log.levels.ERROR, { title = "Firecracker" })
      end
    end)
  end, { desc = desc })
end

vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = { "python", "rust", "markdown" },
  callback = function(event)
    vim.keymap.set("n", "<localleader>f", "<cmd>FirecrackerFmt<cr>", {
      buffer = event.buf,
      desc = "Format with Firecracker devtool",
    })
  end,
})

-- Compile in the devtool image with its musl toolchain; CodeLLDB runs on the
-- host against the shared artifact, with container source paths translated.
local environment = dofile(root .. "/.nvim/init.lua").setup(root)
local bin_crate = "firecracker"

-- Build `bin_crate` and hand its executable path to nvim-dap, or abort the run.
local function debug_build()
  return coroutine.create(function(co)
    local overseer = require("overseer")
    local executable
    local task = overseer.new_task({
      name = "devtool: cargo build -p " .. bin_crate,
      cmd = environment.command({
        "cargo",
        "build",
        "-p",
        bin_crate,
        "--target",
        environment.cargo_target,
        "--message-format=json-render-diagnostics",
      }, {
        env = { CARGO_TERM_PROGRESS_WHEN = "never", CARGO_TERM_COLOR = "never" },
      }),
      cwd = root,
      -- Cargo's JSON stdout must not share a PTY with stderr progress output.
      strategy = { "jobstart", use_terminal = false },
    })

    local function capture_executable(_, lines)
      for _, line in ipairs(lines) do
        local ok, msg = pcall(vim.json.decode, line)
        -- The package has a lib and a bin both named "firecracker"; the lib
        -- artifact comes first with `executable: null` (vim.NIL, which is
        -- truthy), so match on the bin kind and a real path.
        if
          ok
          and msg.reason == "compiler-artifact"
          and msg.target.name == bin_crate
          and vim.list_contains(msg.target.kind, "bin")
          and type(msg.executable) == "string"
        then
          executable = environment.to_host(msg.executable)
          return true
        end
      end
    end

    local function complete_build(_, status)
      task:unsubscribe("on_output_lines", capture_executable)
      vim.schedule(function()
        local dap = require("dap")
        if status ~= overseer.STATUS.SUCCESS then
          coroutine.resume(co, dap.ABORT)
        elseif executable then
          coroutine.resume(co, executable)
        else
          vim.notify(
            "cargo did not report an executable for " .. bin_crate,
            vim.log.levels.ERROR,
            { title = "Firecracker" }
          )
          coroutine.resume(co, dap.ABORT)
        end
      end)
      return true
    end

    task:subscribe("on_output_lines", capture_executable)
    task:subscribe("on_complete", complete_build)

    if not task:start() then
      task:unsubscribe("on_output_lines", capture_executable)
      task:unsubscribe("on_complete", complete_build)
      vim.schedule(function()
        coroutine.resume(co, require("dap").ABORT)
      end)
    end
  end)
end

local api_sock = "/tmp/firecracker-dbg.sock"

-- Function evaluation in LLDB can make syscalls outside the VMM's seccomp
-- allowlist. These launch entries disable seccomp for debugging, not validation.
local firecracker_dap_configs = {
  {
    -- Boot straight from a VM config JSON (kernel_image_path, drives, ...).
    -- Images: see docs/getting-started.md for the kernel and rootfs downloads.
    name = "Firecracker: boot from config file",
    type = "codelldb",
    request = "launch",
    program = debug_build,
    args = function()
      local cfg = vim.fn.input("VM config JSON: ", root .. "/", "file")
      if cfg == "" then
        return require("dap").ABORT
      end
      return { "--no-api", "--no-seccomp", "--config-file", vim.fn.fnamemodify(cfg, ":p") }
    end,
    cwd = root,
    stopOnEntry = false,
    sourceMap = { ["/firecracker"] = environment.root },
    sourceLanguages = { "rust" },
  },
  {
    -- Start with the API socket only; drive it with curl --unix-socket
    -- from a terminal, or the same way the integration tests do.
    name = "Firecracker: API socket (" .. api_sock .. ")",
    type = "codelldb",
    request = "launch",
    program = function()
      vim.fn.delete(api_sock)
      return debug_build()
    end,
    args = { "--api-sock", api_sock, "--no-seccomp" },
    cwd = root,
    stopOnEntry = false,
    sourceMap = { ["/firecracker"] = environment.root },
    sourceLanguages = { "rust" },
  },
}

local dap = require("dap")
dap.providers.configs["firecracker"] = function(bufnr)
  local path = vim.api.nvim_buf_get_name(bufnr)
  if not relative_to_root(path) then
    return {}
  end
  if vim.bo[bufnr].filetype == "rust" then
    return firecracker_dap_configs
  elseif vim.bo[bufnr].filetype == "python" then
    return {
      vim.tbl_extend("force", environment.pytest_config, {
        name = "Firecracker: debug Python tests (devtool)",
        module = "pytest",
        args = { environment.to_container(vim.uv.fs_realpath(path) or path) },
      }),
    }
  end
  return {}
end

vim.api.nvim_create_user_command("FirecrackerDebug", function(opts)
  environment.rust.debuggables(environment, opts.fargs, opts.bang)
end, { nargs = "*", bang = true, desc = "Build and debug a Rust target through devtool" })

local function project_keys(buf)
  local path = vim.api.nvim_buf_get_name(buf)
  if not relative_to_root(path) then
    return
  end
  if vim.bo[buf].filetype == "rust" then
    vim.keymap.set("n", "<leader>dr", "<cmd>FirecrackerDebug<cr>", {
      buffer = buf,
      desc = "Debug Rust Target (devtool)",
    })
  elseif vim.bo[buf].filetype == "python" then
    vim.keymap.set("n", "<leader>dPt", function()
      require("neotest").run.run({ strategy = "dap" })
    end, { buffer = buf, desc = "Debug Test (devtool)" })
    vim.keymap.set("n", "<leader>dPc", function()
      require("nio").run(function()
        local run = require("neotest").run
        local tree = run.get_tree_from_args({})
        while tree and tree:data().type ~= "namespace" do
          tree = tree:parent()
        end
        if tree then
          run.run({ tree:data().id, strategy = "dap" })
        else
          vim.notify("No test class at the cursor", vim.log.levels.INFO)
        end
      end)
    end, { buffer = buf, desc = "Debug Class (devtool)" })
  end
end
vim.api.nvim_create_autocmd({ "FileType", "LspAttach", "BufEnter" }, {
  group = group,
  callback = function(event)
    project_keys(event.buf)
  end,
})
project_keys(vim.api.nvim_get_current_buf())
