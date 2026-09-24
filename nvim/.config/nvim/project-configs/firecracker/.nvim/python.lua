local nio = require("nio")
local lib = require("neotest.lib")

local function normalize(path)
  path = vim.fs.normalize(path)
  if path ~= "/" then
    path = path:gsub("/+$", "")
  end
  return path
end

local function contains(root, path)
  return path == root or vim.startswith(path, root .. "/")
end

local function runner_args(command)
  local args = {}
  local found = false

  for _, arg in ipairs(command) do
    if arg == "--results-file" then
      found = true
    end
    if found then
      args[#args + 1] = arg
    end
  end

  assert(found, "neotest-python runner arguments not found")
  return args
end

local function replace_arg(args, name, value)
  for index, arg in ipairs(args) do
    if arg == name then
      local previous = assert(args[index + 1], name .. " requires a value")
      args[index + 1] = value
      return previous
    end
  end

  error(name .. " not found in neotest-python runner arguments")
end

return function(env)
  local root = normalize(env.root)
  local tests_dir = normalize(env.tests_dir)
  local mount = normalize(env.mount)
  local adapter = require("neotest-python")({
    python = {},
    runner = "pytest",
  })
  local base_filter_dir = adapter.filter_dir
  local base_is_test_file = adapter.is_test_file
  local base_build_spec = adapter.build_spec
  local base_results = adapter.results

  local function host_path(value)
    if type(value) == "string" and contains(mount, value) then
      return env.to_host(value)
    end
    return value
  end

  local function host_value(value)
    if type(value) ~= "table" then
      return host_path(value)
    end

    local mapped = {}
    for key, item in pairs(value) do
      mapped[host_value(key)] = host_value(item)
    end
    return mapped
  end

  local function host_results(results)
    if not results then
      return results
    end

    local mapped = {}
    for id, result in pairs(results) do
      mapped[host_path(id)] = host_value(result)
    end
    return mapped
  end

  adapter.root = function(path)
    path = normalize(path)
    return contains(root, path) and root or nil
  end

  adapter.filter_dir = function(name, rel_path, scan_root)
    if base_filter_dir and not base_filter_dir(name, rel_path, scan_root) then
      return false
    end

    local path = normalize(vim.fs.joinpath(scan_root, rel_path))
    return contains(path, tests_dir) or contains(tests_dir, path)
  end

  adapter.is_test_file = function(path)
    path = normalize(path)
    return contains(tests_dir, path) and base_is_test_file(path)
  end

  adapter.build_spec = function(args)
    local run_dir = env.new_run()
    local results_path = vim.fs.joinpath(run_dir, "results.json")
    local stream_path = vim.fs.joinpath(run_dir, "stream.jsonl")
    local base_args = vim.tbl_extend("force", {}, args, { strategy = "integrated" })
    local spec = assert(base_build_spec(base_args), "neotest-python did not build a run spec")
    local script_args = runner_args(spec.command)
    local old_stream_path = replace_arg(script_args, "--stream-file", env.to_container(stream_path))
    replace_arg(script_args, "--results-file", env.to_container(results_path))

    local passthrough = false
    for index, arg in ipairs(script_args) do
      if arg == "--" then
        passthrough = true
      elseif passthrough and type(arg) == "string" and contains(root, arg) then
        script_args[index] = env.to_container(arg)
      end
    end

    spec.context.stop_stream()
    local initial_stream = lib.files.read(old_stream_path)
    lib.files.write(stream_path, initial_stream)

    nio.scheduler()
    spec.command = env.pytest_command(script_args, run_dir)
    spec.cwd = tests_dir

    if args.strategy == "dap" then
      local strategy = vim.deepcopy(env.pytest_config)
      strategy.name = strategy.name or "Python: Neotest"
      strategy.program = env.python_runner
      strategy.args = vim.deepcopy(script_args)
      spec.strategy = strategy
    else
      spec.strategy = nil
    end

    local stream_data, stop_stream = lib.files.stream_lines(stream_path)
    spec.context.results_path = results_path
    spec.context.stop_stream = stop_stream
    spec.stream = function()
      return function()
        local results = {}
        for _, line in ipairs(stream_data()) do
          local item = vim.json.decode(line, { luanil = { object = true } })
          results[host_path(item.id)] = host_value(item.result)
        end
        return results
      end
    end

    return spec
  end

  adapter.results = function(spec, result, tree)
    local results = base_results(spec, result, tree)
    result.output = host_path(result.output)
    result.output_path = host_path(result.output_path)
    return host_results(results)
  end

  return adapter
end
