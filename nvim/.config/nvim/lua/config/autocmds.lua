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

-- Keep rust-analyzer matched to the active rustup toolchain.
-- `~/.cargo/bin/rust-analyzer` is a rustup proxy: it runs the component of
-- whichever toolchain the project pins. rustup 1.29+ falls back to mason's
-- rust-analyzer when that toolchain lacks the component, so the LSP works
-- immediately; this installs the matching component in the background and
-- asks for a restart once it lands. One attempt per project root per session.
local ra_checked = {}
vim.api.nvim_create_autocmd("FileType", {
	pattern = "rust",
	group = vim.api.nvim_create_augroup("rust_analyzer_component", { clear = true }),
	callback = function(ev)
		if vim.fn.executable("rustup") ~= 1 then
			return
		end
		local root = vim.fs.root(ev.buf, { "rust-toolchain.toml", "rust-toolchain", "Cargo.toml" }) or vim.fn.getcwd()
		if ra_checked[root] then
			return
		end
		ra_checked[root] = true
		vim.system({ "rustup", "which", "rust-analyzer" }, { cwd = root }, function(which)
			if which.code == 0 then
				return
			end
			vim.system({ "rustup", "component", "add", "rust-analyzer" }, { cwd = root }, function(add)
				vim.schedule(function()
					if add.code == 0 then
						vim.notify(
							"Installed rust-analyzer for this project's toolchain.\nRun :RustAnalyzer restart to switch to it.",
							vim.log.levels.INFO,
							{ title = "rustup" }
						)
					else
						vim.notify(
							"rustup component add rust-analyzer failed:\n" .. (add.stderr or ""),
							vim.log.levels.WARN,
							{
								title = "rustup",
							}
						)
					end
				end)
			end)
		end)
	end,
})
