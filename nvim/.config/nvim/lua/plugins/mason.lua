return {
	-- LazyVim already installs stylua and shfmt; only list additions.
	{
		"mason-org/mason.nvim",
		opts = {
			ensure_installed = {
				"shellcheck",
			},
		},
	},
}
