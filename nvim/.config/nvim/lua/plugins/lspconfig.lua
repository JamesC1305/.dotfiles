-- Prefer mason's clangd (23.x) over the AL2023 system one (15.x) for kernel
-- browsing. Mason's bin dir is appended to PATH (see mason.lua), so a bare
-- "clangd" would resolve to /usr/bin/clangd; point at the mason binary
-- directly and fall back to PATH until mason has installed it.
local mason_clangd = vim.fn.stdpath("data") .. "/mason/bin/clangd"

return {
	{
		"neovim/nvim-lspconfig",
		---@class PluginLspOpts
		opts = {
			---@type lspconfig.options
			servers = {
				clangd = {
					cmd = {
						vim.uv.fs_stat(mason_clangd) and mason_clangd or "clangd",
						"--background-index",
						"-j=" .. vim.uv.available_parallelism(),
						"--query-driver=/usr/bin/**/clang-*,/bin/clang,/home/**/clang,/bin/clang++,/usr/bin/gcc,/usr/bin/g++",
						"--clang-tidy",
						"--header-insertion=never",
						"--enable-config",
						"--completion-style=detailed",
						"--function-arg-placeholders",
						"--fallback-style=llvm",
					},
				},
			},
		},
	},
	-- lang.rust hands rust-analyzer to rustaceanvim and disables the lspconfig
	-- entry, so rust-analyzer settings live here instead of in `servers`.
	{
		"mrcjkb/rustaceanvim",
		opts = {
			server = {
				-- rustaceanvim spawns the server with Neovim's cwd, so the bare
				-- "rust-analyzer" rustup proxy would pick the toolchain of wherever nvim
				-- was launched. Resolve the binary for the project root instead so
				-- rust-toolchain.toml is honoured. When the pinned toolchain has no
				-- rust-analyzer component, leave the proxy alone: rustup then runs the
				-- default toolchain's server (or mason's copy if that has none) and
				-- autocmds.lua installs the missing component.
				settings = function(project_root, default_settings)
					local settings = require("rustaceanvim.config.server").load_rust_analyzer_settings(
						project_root,
						{ default_settings = default_settings }
					)
					if project_root and not vim.tbl_get(settings, "rust-analyzer", "server", "path") then
						local which = vim.system(
							{ "rustup", "which", "rust-analyzer" },
							{ cwd = project_root, env = { RUSTUP_AUTO_INSTALL = "0" } }
						):wait(2000)
						if which.code == 0 then
							settings["rust-analyzer"] = settings["rust-analyzer"] or {}
							settings["rust-analyzer"].server = settings["rust-analyzer"].server or {}
							settings["rust-analyzer"].server.path = vim.trim(which.stdout)
						end
					end
					return settings
				end,
				default_settings = {
					["rust-analyzer"] = {
						workspace = {
							symbol = {
								search = {
									limit = 2048,
								},
							},
						},
					},
				},
			},
		},
	},
}
