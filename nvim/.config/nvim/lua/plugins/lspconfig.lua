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
						"clangd",
						"-j=" .. vim.fn.system("nproc"):gsub("%s+", ""),
						"--query-driver=/usr/bin/**/clang-*,/bin/clang,/home/**/clang,/bin/clang++,/usr/bin/gcc,/usr/bin/g++",
						"--clang-tidy",
						"--log=verbose",
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
