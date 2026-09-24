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
				rust_analyzer = {
					settings = {
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
}
