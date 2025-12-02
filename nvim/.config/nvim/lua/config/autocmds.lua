vim.api.nvim_create_autocmd("User", {
	pattern = "LazyUpdate",
	callback = function()
		local config_dir = vim.fn.stdpath("config")
		vim.fn.system(
			string.format(
				"git -C %s diff --quiet lazy-lock.json || (git -C %s add lazy-lock.json && git -C %s commit -m 'chore: update lazy-lock.json')",
				config_dir,
				config_dir,
				config_dir
			)
		)
	end,
})
