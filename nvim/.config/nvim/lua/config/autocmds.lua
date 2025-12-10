vim.api.nvim_create_autocmd("User", {
	pattern = "LazyUpdate",
	callback = function()
		local config_dir = vim.fn.stdpath("config")

		-- Check for lockfile changes
		vim.fn.system(string.format("git -C %s diff --quiet lazy-lock.json", config_dir))

		if vim.v.shell_error ~= 0 then
			-- Set Git config
			vim.fn.system(string.format("git -C %s config user.name 'James Curtis'", config_dir))
			vim.fn.system(string.format("git -C %s config user.email 'jamescurtis2003@live.co.uk'", config_dir))

			-- Add and commit
			vim.fn.system(string.format("git -C %s add lazy-lock.json", config_dir))
			vim.fn.system(string.format("git -C %s commit -m 'chore: update lazy-lock.json'", config_dir))
		end
	end,
})
