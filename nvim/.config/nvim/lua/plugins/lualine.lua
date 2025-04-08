return {
	-- -- the opts function can also be used to change the default opts:
	-- {
	-- 	"nvim-lualine/lualine.nvim",
	-- 	event = "VeryLazy",
	-- 	opts = function(_, opts)
	-- 		table.insert(opts.sections.lualine_x, "😄")
	-- 	end,
	-- },
	-- or you can return new options to override all the defaults
	{
		"nvim-lualine/lualine.nvim",
		event = "VeryLazy",
		opts = function()
			return {
				--[[add your custom lualine config here]]
			}
		end,
		sections = function()
			return {
				-- Add the macro recording status in the mode section
				lualine_a = {
					function()
						local reg = vim.fn.reg_recording()
						-- If a macro is being recorded, show "Recording @<register>"
						if reg ~= "" then
							return "Recording @" .. reg
						else
							-- Get the full mode name using nvim_get_mode()
							local mode = vim.api.nvim_get_mode().mode
							local mode_map = {
								n = "NORMAL",
								i = "INSERT",
								v = "VISUAL",
								V = "V-LINE",
								["^V"] = "V-BLOCK",
								c = "COMMAND",
								R = "REPLACE",
								s = "SELECT",
								S = "S-LINE",
								["^S"] = "S-BLOCK",
								t = "TERMINAL",
							}

							-- Return the full mode name
							return mode_map[mode] or mode:upper()
						end
					end,
				},
			}
		end,
	},
}
