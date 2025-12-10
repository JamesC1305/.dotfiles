return {
	-- fzf-lua configuration for file and symbol search
	{
		"ibhagwan/fzf-lua",
		keys = {
			-- Browse plugin files
			{
				"<leader>pf",
				function()
					require("fzf-lua").files({ cwd = require("lazy.core.config").options.root })
				end,
				desc = "Find Plugin File",
			},
			-- Grep search
			{
				"<leader>ps",
				function()
					require("fzf-lua").live_grep()
				end,
				desc = "Grep Search",
			},
			-- Code symbol search (defined in synbols-outline.lua)
			{
				"<leader>pw",
				function()
					require("fzf-lua").lsp_live_workspace_symbols()
				end,
				desc = "Workspace Search",
			},
			-- Symbol references
			{
				"<leader>pg",
				function()
					require("fzf-lua").git_files()
				end,
				desc = "Git files",
			},
			{
				"<leader>pr",
				function()
					require("fzf-lua").lsp_references()
				end,
				desc = "Symbol References",
			},
			-- Treesitter search
			{
				"<leader>pt",
				function()
					require("fzf-lua").treesitter()
				end,
				desc = "Treesitter",
			},
		},
		opts = {
			-- fzf-lua specific options
			previewers = {
				bat = {
					theme = "gruvbox",
				},
			},
			winopts = {
				preview = {
					vertical = "down:40%",
				},
				height = 0.85,
			},
		},
	},

	-- Ensure you have the necessary fzf dependencies
	{
		"junegunn/fzf",
		run = "./install --all", -- for fzf to work, you need to install it
		config = function()
			-- No extra config required for fzf-lua itself
		end,
	},
}
