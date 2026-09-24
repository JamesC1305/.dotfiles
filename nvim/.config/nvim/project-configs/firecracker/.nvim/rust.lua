local M = {}
local last = {}

local function copy_list(values)
  return vim.deepcopy(values or {})
end

local function append(dst, values)
  for _, value in ipairs(values or {}) do
    table.insert(dst, value)
  end
  return dst
end

local function has(values, expected)
  for _, value in ipairs(values) do
    if value == expected then
      return true
    end
  end
  return false
end

local function map_arg(env, arg)
  if type(arg) ~= "string" then
    return arg
  end
  local option, value = arg:match("^(%-%-[^=]+=)(.*)$")
  if option then
    return option .. env.to_container(value)
  end
  return env.to_container(arg)
end

local function map_args(env, args)
  local mapped = {}
  for _, arg in ipairs(args) do
    table.insert(mapped, map_arg(env, arg))
  end
  return mapped
end

-- Resolved $HOME, so host paths are recognised when $HOME is a symlink.
local home_real = vim.uv.fs_realpath(vim.uv.os_homedir() or "")

local function is_host_home_path(path)
  return vim.startswith(path, "/home/") or (home_real ~= nil and vim.startswith(path, home_real .. "/"))
end

local function container_env(env, values)
  local ret = vim.empty_dict()
  for key, value in pairs(values or {}) do
    local mapped = map_arg(env, value)
    -- rust-analyzer supplies a host toolchain path that is not mounted.
    if key ~= "RUSTC_TOOLCHAIN" and not (type(mapped) == "string" and is_host_home_path(mapped)) then
      ret[key] = mapped
    end
  end
  return ret
end

local function add_target(args, target)
  for _, arg in ipairs(args) do
    if arg == "--" then
      break
    end
    if arg == "--target" or vim.startswith(arg, "--target=") then
      return args
    end
  end
  table.insert(args, math.min(2, #args + 1), "--target")
  table.insert(args, math.min(3, #args + 1), target)
  return args
end

local function standard_args(runnable)
  local cargo = require("rustaceanvim.runnables").as_cargo_runnable(runnable)
  if not cargo then
    return
  end
  local args = copy_list(cargo.args.cargoArgs)
  append(args, cargo.args.cargoExtraArgs)
  table.insert(args, "--")
  append(args, cargo.args.executableArgs)
  return args
end

local function copy_tree(tree)
  local Tree = require("neotest.types").Tree
  return Tree.from_list(vim.deepcopy(tree:to_list()), function(position)
    return position.id
  end)
end

local function integrated_spec(base, run_args)
  local tree = copy_tree(run_args.tree)
  local position = tree:data()
  local runnable = position.runnable
  local args = runnable and standard_args(runnable)
  if args then
    local cargo = runnable.args
    position.runnable = {
      kind = "shell",
      label = runnable.label,
      location = vim.deepcopy(runnable.location),
      args = {
        program = "cargo",
        args = args,
        cwd = cargo.workspaceRoot,
        environment = vim.deepcopy(cargo.environment),
      },
    }
  end
  local copied = vim.tbl_extend("force", {}, run_args, {
    tree = tree,
    strategy = "integrated",
  })
  return base.build_spec(copied)
end

local function wrap_spec(env, spec)
  if not spec or not spec.command then
    return spec
  end
  local command = copy_list(spec.command)
  if command[1] == "cargo" then
    local args = {}
    for index = 2, #command do
      table.insert(args, command[index])
    end
    add_target(args, env.cargo_target)
    command = { "cargo" }
    append(command, args)
  end
  require("nio").scheduler()
  command = map_args(env, command)
  spec.command = env.command(command, {
    cwd = spec.cwd or env.root,
    env = container_env(env, spec.env),
  })
  spec.cwd = env.root
  spec.env = nil
  return spec
end

local function compile_args(env, runnable)
  local cargo = require("rustaceanvim.runnables").as_cargo_runnable(runnable)
  assert(cargo, "Rust runnable is not a Cargo target")
  local args = copy_list(cargo.args.cargoArgs)
  assert(args[1] == "run" or args[1] == "test", "Rust target is not a binary or test")
  if args[1] == "run" then
    args[1] = "build"
  elseif not has(args, "--no-run") then
    table.insert(args, 2, "--no-run")
  end
  for _, arg in ipairs(cargo.args.cargoExtraArgs or {}) do
    if not has(args, arg) then
      table.insert(args, arg)
    end
  end
  local message_format = false
  for index, arg in ipairs(args) do
    if arg == "--message-format" then
      args[index + 1] = "json-render-diagnostics"
      message_format = true
    elseif vim.startswith(arg, "--message-format=") then
      args[index] = "--message-format=json-render-diagnostics"
      message_format = true
    end
  end
  if not message_format then
    table.insert(args, "--message-format=json-render-diagnostics")
  end
  add_target(args, env.cargo_target)
  return cargo, map_args(env, args)
end

local function artifact(stdout)
  local executables = {}
  for line in (stdout or ""):gmatch("[^\r\n]+") do
    local ok, message = pcall(vim.json.decode, line)
    local kinds = ok and type(message) == "table" and message.target and message.target.kind or {}
    if
      ok
      and message.reason == "compiler-artifact"
      and type(message.executable) == "string"
      and (has(kinds, "bin") or has(kinds, "test") or (message.profile and message.profile.test))
    then
      executables[message.executable] = true
    end
  end
  local paths = vim.tbl_keys(executables)
  table.sort(paths)
  assert(#paths > 0, "Cargo did not report a binary or test executable")
  assert(#paths == 1, "Cargo reported multiple binary or test executables")
  return paths[1]
end

local function system(command, options)
  return require("nio").wrap(function(argv, opts, callback)
    vim.system(argv, opts, callback)
  end, 3)(command, options)
end

local function debug_config(env, runnable)
  local nio = require("nio")
  nio.scheduler()
  local cargo, args = compile_args(env, runnable)
  local process_env = vim.tbl_extend("force", container_env(env, cargo.args.environment), {
    CARGO_TERM_COLOR = "never",
    CARGO_TERM_PROGRESS_WHEN = "never",
  })
  local command = { "cargo" }
  append(command, args)
  command = env.command(command, {
    cwd = cargo.args.workspaceRoot or env.root,
    env = process_env,
  })
  local result = system(command, { cwd = env.root, text = true })
  assert(result.code == 0, vim.trim(result.stderr or result.stdout or "Cargo compilation failed"))
  local config = {
    name = runnable.label,
    type = "codelldb",
    request = "launch",
    program = env.to_host(artifact(result.stdout)),
    args = copy_list(cargo.args.executableArgs),
    cwd = env.root,
    sourceMap = { [env.mount] = env.root },
  }
  config.env = vim.tbl_extend("force", vim.empty_dict(), cargo.args.environment or {})
  config.env.RUSTC_TOOLCHAIN = nil
  return config
end

local function notify_error(err)
  vim.notify(tostring(err), vim.log.levels.ERROR, { title = "Firecracker Rust" })
end

function M.adapter(env)
  local base = require("rustaceanvim.neotest")()
  local adapter = setmetatable({ name = "rustaceanvim-devtool" }, { __index = base })
  adapter.root = function(path)
    return (path == env.root or vim.startswith(path, env.root .. "/")) and env.root or nil
  end
  adapter.filter_dir = function(name)
    return name ~= "build" and name ~= "target" and name ~= ".git" and name ~= ".venv" and name ~= "resources"
  end
  adapter.is_test_file = function(path)
    return vim.startswith(path, env.root .. "/src/") and base.is_test_file(path)
  end
  adapter.build_spec = function(run_args)
    local nio = require("nio")
    nio.scheduler()
    local spec = integrated_spec(base, run_args)
    if not spec then
      return
    end
    if run_args.strategy ~= "dap" then
      return wrap_spec(env, spec)
    end
    local runnable = run_args.tree:data().runnable
    local ok, strategy = pcall(debug_config, env, vim.deepcopy(runnable))
    if not ok then
      notify_error(strategy)
      return { cwd = env.root, context = spec.context }
    end
    return {
      cwd = env.root,
      context = spec.context,
      strategy = strategy,
    }
  end
  return adapter
end

local function arguments(args)
  if type(args) == "table" then
    return args
  end
  if type(args) == "string" and args ~= "" then
    return vim.split(args, "%s+", { trimempty = true })
  end
  return {}
end

local function adjusted(runnable, args)
  local runnables = require("rustaceanvim.runnables")
  local values = runnables.apply_exec_args_override(args, { vim.deepcopy(runnable) })
  return values[1]
end

local function debug(env, runnable, args)
  local selected = adjusted(runnable, args)
  last[env.root] = vim.deepcopy(selected)
  require("nio").run(function()
    local ok, config = pcall(debug_config, env, selected)
    require("nio").scheduler()
    if not ok then
      notify_error(config)
      return
    end
    require("dap").run(config)
  end)
end

function M.debuggables(env, args, bang)
  args = arguments(args)
  if bang then
    if not last[env.root] then
      notify_error("No previous Firecracker Rust target")
      return
    end
    debug(env, last[env.root], args)
    return
  end
  local ra = require("rustaceanvim.rust_analyzer")
  local params = {
    textDocument = vim.lsp.util.make_text_document_params(0),
    position = nil,
  }
  local found = ra.buf_request(0, "experimental/runnables", params, function(err, result)
    if err then
      notify_error(err.message or err)
      return
    end
    local runnables = require("rustaceanvim.runnables")
    local choices = vim.tbl_filter(function(runnable)
      local cargo = runnables.as_cargo_runnable(runnable)
      local command = cargo and cargo.args.cargoArgs[1]
      return command == "run" or command == "test"
    end, result or {})
    if #choices == 0 then
      notify_error("No binary or test targets found")
      return
    end
    local labels = vim.tbl_map(function(runnable)
      local suffix = #args > 0 and " -- " .. table.concat(args, " ") or ""
      return runnable.label .. suffix
    end, choices)
    vim.ui.select(labels, { prompt = "Debuggables", kind = "rust-tools/debuggables" }, function(_, choice)
      if choice then
        debug(env, choices[choice], args)
      end
    end)
  end)
  if not found then
    notify_error("No rust-analyzer client supports experimental/runnables")
  end
end

return M
