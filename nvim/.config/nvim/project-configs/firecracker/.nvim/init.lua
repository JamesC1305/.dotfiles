local M = {}
local environments = rawget(_G, "firecracker_devtool_environments") or {}
_G.firecracker_devtool_environments = environments

function M.setup(root)
  root = vim.uv.fs_realpath(root) or root
  if environments[root] then
    return environments[root]
  end
  local transport = root .. "/.nvim/devtool.py"
  local python = vim.fn.exepath("python3")
  local runner = require("lazy.core.config").plugins["neotest-python"].dir
  local env = { root = root, mount = "/firecracker", tests_dir = root .. "/tests" }
  env.cargo_target = vim.uv.os_uname().machine .. "-unknown-linux-musl"
  env.state = root .. "/build/.nvim-devtool/" .. vim.fn.getpid()
  local run_id = 0

  function env.to_container(path)
    if type(path) == "string" and (path == root or vim.startswith(path, root .. "/")) then
      return env.mount .. path:sub(#root + 1)
    end
    return path
  end

  function env.to_host(path)
    if type(path) == "string" and (path == env.mount or vim.startswith(path, env.mount .. "/")) then
      return root .. path:sub(#env.mount + 1)
    end
    return path
  end

  function env.new_run()
    run_id = run_id + 1
    local dir = env.state .. "/run-" .. run_id
    vim.fn.mkdir(dir, "p")
    return dir
  end

  -- The transport starts or reuses devtool when the command executes. Constructing
  -- a command never blocks Neovim on Docker or a dependency download.
  function env.command(argv, opts)
    opts = opts or {}
    local cmd = {
      python,
      transport,
      "exec",
      "--root",
      root,
      "--state",
      env.state,
      "--owner",
      tostring(vim.fn.getpid()),
      "--runner",
      runner,
      "--cwd",
      env.to_container(opts.cwd or root),
      "--env",
      vim.json.encode(vim.tbl_isempty(opts.env or {}) and vim.empty_dict() or opts.env),
      "--",
    }
    return vim.list_extend(cmd, argv)
  end

  env.python_runner = env.to_container(env.state) .. "/neotest.py"
  env.python_debug_type = "firecracker-python-" .. vim.fn.sha256(root):sub(1, 10)
  env.pytest_config = {
    type = env.python_debug_type,
    request = "launch",
    python = "python3",
    cwd = "/firecracker/tests",
    pathMappings = { { localRoot = root, remoteRoot = env.mount } },
    justMyCode = false,
    subProcess = true,
    console = "internalConsole",
  }

  function env.pytest_command(args)
    return env.command(vim.list_extend({
      "python3",
      env.to_container(env.state) .. "/transport.py",
      "pytest",
      "--state",
      env.to_container(env.state),
      "--",
    }, args))
  end

  local dap = require("dap")
  dap.adapters[env.python_debug_type] = function(callback)
    local package = "debugpy"
    local receipt = vim.fn.stdpath("data") .. "/mason/packages/debugpy/mason-receipt.json"
    local ok, data = pcall(function()
      return vim.json.decode(table.concat(vim.fn.readfile(receipt), "\n"))
    end)
    local version = ok and data.source and data.source.id and data.source.id:match("@([%d%.]+)")
    if version then
      package = package .. "==" .. version
    end
    local prepare = env.command({
      "python3",
      env.to_container(env.state) .. "/transport.py",
      "prepare-debugpy",
      "--package",
      package,
    })
    vim.system(prepare, { cwd = root, text = true, timeout = 120000 }, function(result)
      vim.schedule(function()
        if result.code ~= 0 then
          vim.notify("Devtool debugger setup failed:\n" .. (result.stderr or ""), vim.log.levels.ERROR)
          callback(nil)
          return
        end
        local path = vim.trim(result.stdout)
        local cmd = env.command({
          "python3",
          env.to_container(env.state) .. "/transport.py",
          "pytest",
          "--state",
          env.to_container(env.state),
          "--debug",
          "--python-path",
          path,
        })
        callback({
          type = "executable",
          command = cmd[1],
          args = vim.list_slice(cmd, 2),
          options = { cwd = root, initialize_timeout_sec = 120 },
        })
      end)
    end)
  end

  -- The keeper notices editor exit. Do not hold VimLeavePre for Docker teardown.
  vim.api.nvim_create_user_command("DevtoolStop", function()
    vim.system({ python, transport, "stop", "--state", env.state }, { text = true }, function(result)
      vim.schedule(function()
        vim.notify(
          result.code == 0 and "Devtool container stopped" or (result.stderr or "Devtool stop failed"),
          result.code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR
        )
      end)
    end)
  end, { desc = "Stop this editor's devtool container" })

  -- Load Neotest synchronously before installing project-specific adapters.
  local neotest = require("neotest")
  env.rust = dofile(root .. "/.nvim/rust.lua")
  neotest.setup_project(root, {
    adapters = { dofile(root .. "/.nvim/python.lua")(env), env.rust.adapter(env) },
    discovery = { enabled = false },
    running = { concurrent = false },
  })
  local watched = {}
  local function refresh_tests(buf)
    if vim.startswith(vim.api.nvim_buf_get_name(buf), root .. "/src/") then
      pcall(vim.api.nvim_exec_autocmds, "BufAdd", {
        group = "neotest.Client",
        buffer = buf,
        modeline = false,
      })
    end
  end
  vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(event)
      local client = vim.lsp.get_client_by_id(event.data.client_id)
      local path = vim.api.nvim_buf_get_name(event.buf)
      if not client or client.name ~= "rust-analyzer" or not vim.startswith(path, root .. "/src/") then
        return
      end
      vim.schedule(function()
        refresh_tests(event.buf)
      end)
      if not watched[client.id] then
        watched[client.id] = true
        local original = client.handlers["experimental/serverStatus"]
        local refreshed = false
        client.handlers["experimental/serverStatus"] = function(err, result, ctx, config)
          if original then
            original(err, result, ctx, config)
          end
          if not refreshed and result and result.quiescent then
            refreshed = true
            vim.schedule(function()
              for buf in pairs(client.attached_buffers) do
                refresh_tests(buf)
              end
            end)
          end
        end
      end
    end,
  })
  environments[root] = env
  return env
end

return M
