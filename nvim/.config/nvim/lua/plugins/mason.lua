return {
	-- LazyVim already installs stylua and shfmt; only list additions.
	{
		"mason-org/mason.nvim",
		opts = {
			-- Put mason's bin dir after the existing PATH so toolchain-managed
			-- binaries (rustup's rust-analyzer, /usr/bin/clangd, project venvs)
			-- win over mason downloads of the same name.
			PATH = "append",
			ensure_installed = {
				"shellcheck",
			},
		},
	},
}
