return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	---@type snacks.Config
	opts = {
		-- your configuration comes here
		-- or leave it empty to use the default settings
		-- refer to the configuration section below
		bigfile = { enabled = true },
		dashboard = {
			width = 80,
			sections = {
				{ section = "keys", gap = 1, padding = 1 },
				{ pane = 1, icon = " ", title = "Recent Files", section = "recent_files", indent = 2, padding = 1 },
				{ pane = 1, icon = " ", title = "Projects", section = "projects", indent = 2, padding = 1 },
				{
					pane = 2,
					icon = " ",
					desc = "Browse Repo",
					padding = 1,
					key = "b",
					action = function()
						Snacks.gitbrowse()
					end,
				},
				function()
					local in_git = Snacks.git.get_root() ~= nil
					local cmds = {
						{
							icon = " ",
							title = "Git Status",
							cmd = "git --no-pager diff --stat -B -M -C",
							height = 12,
						},
						{
							icon = " ",
							title = "Open PRs",
							cmd = "gh pr list -L 3",
							key = "P",
							action = function()
								vim.fn.jobstart("gh pr list --web", { detach = true })
							end,
							height = 10,
						},
						{
							title = "Open Issues",
							cmd = "gh issue list -L 3",
							key = "i",
							action = function()
								vim.fn.jobstart("gh issue list --web", { detach = true })
							end,
							icon = " ",
							height = 10,
						},
					}
					return vim.tbl_map(function(cmd)
						return vim.tbl_extend("force", {
							pane = 2,
							section = "terminal",
							enabled = in_git,
							padding = 1,
							ttl = 5 * 60,
							indent = 3,
						}, cmd)
					end, cmds)
				end,
				{ section = "startup" },
			},
		},
		explorer = { enabled = false },
		-- explorer = {
		-- 	enabled = true,
		-- 	supports_live = true,
		-- 	tree = true,
		-- 	watch = true,
		-- 	diagnostics = true,
		-- 	diagnostics_open = false,
		-- 	git_status = true,
		-- 	git_status_open = false,
		-- 	git_untracked = true,
		-- 	follow_file = true,
		-- 	focus = "list",
		-- },
		indent = { enabled = true },
		input = { enabled = true },
		notifier = { enabled = true },
		-- picker = { enabled = true },
		quickfile = { enabled = true },
		scope = { enabled = true },
		scroll = { enabled = false },
		statuscolumn = { enabled = false }, -- we set this in options.lua
		toggle = { map = LazyVim.safe_keymap_set },
		words = { enabled = true },
	},
	-- keys = {
	-- 	{
	-- 		"<leader>e",
	-- 		function()
	-- 			Snacks.picker.explorer({ watch = true })
	-- 		end,
	-- 		desc = "File Explorer",
	-- 	},
	-- },
}
