return {
	-- fzf-lua is LazyVim's active picker here (editor.fzf extra, selected via
	-- vim.g.lazyvim_picker in options.lua). These are extra bindings on top.
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
			-- Code symbol search
			{
				"<leader>pw",
				function()
					require("fzf-lua").lsp_live_workspace_symbols()
				end,
				desc = "Workspace Search",
			},
			{
				"<leader>pg",
				function()
					require("fzf-lua").git_files()
				end,
				desc = "Git files",
			},
			-- Symbol references
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

	-- Provides the fzf binary (not installed system-wide); fzf-lua falls back to
	-- fzf#exec() from this plugin when `fzf` is not on $PATH.
	{
		"junegunn/fzf",
		build = "./install --bin",
	},
}
