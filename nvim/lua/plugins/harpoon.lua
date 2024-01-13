return {
	"theprimeagen/harpoon",
	keys = {
		{
			"<leader>a",
			function()
				require("harpoon.mark").add_file()
			end,
			desc = "Add to Harpoon",
		},
		{
			"<C-e>",
			function()
				require("harpoon.ui").toggle_quick_menu()
			end,
			desc = "Harpoon Menu",
		},
		{
			"<C-p>",
			function()
				require("harpoon.ui").nav_next()
			end,
			desc = "Harpoon Next",
		},
		{
			"<C-n>",
			function()
				require("harpoon.ui").nav_prev()
			end,
			desc = "Harpoon Previous",
		},
	},
}
