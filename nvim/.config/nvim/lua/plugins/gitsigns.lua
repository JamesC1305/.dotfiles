return {
	"lewis6991/gitsigns.nvim",
	opts = {
		current_line_blame = true,
	},
	keys = {
		{
			"<leader>gB",
			function()
				require("gitsigns").blame({ full = true })
			end,
			desc = "Git blame file",
		},
		{
			"<leader>gb",
			function()
				require("gitsigns").blame_line()
			end,
			desc = "Git blame line",
		},
	},
}
