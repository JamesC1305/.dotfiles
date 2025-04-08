return {
	"mbbill/undotree",
	keys = {
		{
			"<leader>U",
			function()
				vim.cmd.UndotreeToggle()
			end,
			desc = "Toggle Undotree",
		},
	},
	config = function()
		vim.g.undotree_WindowLayout = 4
	end,
}
