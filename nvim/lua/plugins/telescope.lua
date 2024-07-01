return {
	-- change some telescope options and a keymap to browse plugin files
	{
		"nvim-telescope/telescope.nvim",
		keys = {
      -- add a keymap to browse plugin files
      -- stylua: ignore
      {
        "<leader>pf",
        function() require("telescope.builtin").find_files({ cwd = require("lazy.core.config").options.root }) end,
        desc = "Find Plugin File",
      },
			{
				"<leader>ps",
				function()
					require("telescope.builtin").grep_string({ search = vim.fn.input("Grep > ") })
				end,
				desc = "Grep Search",
			},
			{
				"<leader>pc",
				function()
					require("telescope.builtin").lsp_workspace_symbols({})
				end,
				desc = "Code symbol search",
			},
			{
				"<leader>pr",
				function()
					require("telescope.builtin").lsp_references({})
				end,
				desc = "Symbol references",
			},
			{
				"<leader>pt",
				function()
					require("telescope.builtin").treesitter()
				end,
				desc = "Treesitter",
			},
		},
		-- change some options
		opts = {
			defaults = {
				layout_strategy = "horizontal",
				layout_config = { prompt_position = "top" },
				sorting_strategy = "ascending",
				winblend = 0,
			},
		},
	},

	-- add telescope-fzf-native
	{
		"telescope.nvim",
		dependencies = {
			"nvim-telescope/telescope-fzf-native.nvim",
			build = "make",
			config = function()
				require("telescope").load_extension("fzf")
			end,
		},
	},
}
