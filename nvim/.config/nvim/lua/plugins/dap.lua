return {
	{
		"mfussenegger/nvim-dap",
		keys = {
			{
				"<leader>dL",
				function()
					vim.ui.input({ prompt = "Log message: " }, function(message)
						if message == nil or message == "" then
							return
						end
						require("dap").set_breakpoint(nil, nil, message)
					end)
				end,
				mode = "n",
				desc = "Set Logpoint",
			},
		},
		opts = function()
			local dap = require("dap")
			local name = "Native: Attach to process"
			local native_filetypes = { c = true, cpp = true, rust = true }

			dap.providers.configs["user.native_attach"] = function(bufnr)
				local filetype = vim.b[bufnr]["dap-srcft"] or vim.bo[bufnr].filetype
				if not native_filetypes[filetype] then
					return {}
				end

				for _, configuration in ipairs(dap.configurations[filetype] or {}) do
					if configuration.request == "attach" and configuration.type == "codelldb" then
						return {}
					end
				end

				return {
					{
						name = name,
						type = "codelldb",
						request = "attach",
						pid = require("dap.utils").pick_process,
						cwd = "${workspaceFolder}",
					},
				}
			end
		end,
	},
}
