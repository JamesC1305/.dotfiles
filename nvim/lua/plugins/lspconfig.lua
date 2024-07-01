return {
	{
		"neovim/nvim-lspconfig",
		dependencies = {},
		---@class PluginLspOpts
		opts = {
			---@type lspconfig.options
			servers = {
				-- tsserver will be automatically installed with mason and loaded with lspconfig
				--tsserver = {},
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
			},
			keys = {
				{
					"gD",
					function()
						vim.lsp.buf.definition()
					end,
					desc = "Get Definition",
				},
				{
					"K",
					function()
						vim.lsp.buf.hover()
					end,
					desc = "Hover",
				},
				{
					"gi",
					function()
						vim.lsp.buf.implementation()
					end,
					desc = "Get Implementation",
				},
				{
					"gr",
					function()
						vim.lsp.buf.references()
					end,
					desc = "Get References",
				},
				{
					"gds",
					function()
						vim.lsp.buf.document_symbol()
					end,
					desc = "Get Document Symbol",
				},
				{
					"gws",
					function()
						vim.lsp.buf.workspace_symbol()
					end,
					desc = "Get Workspace Symbol",
				},
				{
					"<leader>cl",
					function()
						vim.lsp.codelens.run()
					end,
					desc = "Run Codelens",
				},
				{
					"<leader>sh",
					function()
						vim.lsp.buf.signature_help()
					end,
					desc = "Signature Help",
				},
				{
					"<leader>rn",
					function()
						vim.lsp.buf.rename()
					end,
					desc = "Rename",
				},
				{
					"<leader>f",
					function()
						vim.lsp.buf.format()
					end,
					desc = "Format",
				},
				{
					"<leader>ca",
					function()
						vim.lsp.buf.code_action()
					end,
					desc = "Code Actions",
				},
				{
					"<leader>aa",
					function()
						vim.diagnostic.setqflist()
					end,
					desc = "All workspace diagnostics",
				},
				{
					"<leader>ae",
					function()
						vim.diagnostic.setqflist({ severity = "E" })
					end,
					desc = "All Workspace Errors",
				},
				{
					"<leader>aw",
					function()
						vim.diagnostic.setqflist({ severity = "W" })
					end,
					desc = "All Workspace Errors",
				},
				{
					"<leader>d",
					function()
						vim.diagnostic.getloclist()
					end,
					desc = "Get Buffer Diagnostics",
				},
				{
					"[c",
					function()
						vim.diagnostic.goto_prev()
					end,
					desc = "Go to Previous",
				},
				{
					"]c",
					function()
						vim.diagnostic.goto_next()
					end,
					desc = "Go to Next",
				},
			},
			-- you can do any additional lsp server setup here
			-- return true if you don't want this server to be setup with lspconfig
			---@type table<string, fun(server:string, opts:_.lspconfig.options):boolean?>
			--setup = {
			--  -- example to setup with typescript.nvim
			--tsserver = function(_, opts)
			--require("typescript").setup({ server = opts })
			--return true
			--end,
			-- Specify * to use this function as a fallback for any server
			-- ["*"] = function(server, opts) end,
			--},
		},
	},
}
