-- Options are automatically loaded before lazy.nvim startup
-- Default options: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Route the system clipboard through OSC 52 escape sequences.
-- Needed under mosh, which sets SSH_CONNECTION but not SSH_TTY, so Neovim's
-- automatic OSC 52 fallback never triggers. This wires it explicitly so yanks
-- reach the local machine's clipboard via the terminal (tmux forwards OSC 52).
local osc52 = require("vim.ui.clipboard.osc52")

local function tmux_copy(lines)
	local text = table.concat(lines, "\n")
	local result = vim.system({ "tmux", "load-buffer", "-w", "-" }, { stdin = text, text = true }):wait()
	if result.code ~= 0 then
		vim.notify("tmux clipboard copy failed: " .. (result.stderr or ""), vim.log.levels.WARN)
	end
end

local copy_plus = vim.env.TMUX and tmux_copy or osc52.copy("+")
local copy_star = vim.env.TMUX and tmux_copy or osc52.copy("*")

vim.g.clipboard = {
	name = "OSC 52",
	copy = {
		["+"] = copy_plus,
		["*"] = copy_star,
	},
	paste = {
		["+"] = osc52.paste("+"),
		["*"] = osc52.paste("*"),
	},
}

-- Make plain yanks (y, yy, dd, etc.) go to the system clipboard.
vim.opt.clipboard = "unnamedplus"

-- Allow trusted project-local config such as Firecracker's .nvim.lua.
vim.opt.exrc = true

-- Picker/explorer selection. Without these, LazyVim falls back to defaults that
-- depend on `install_version` in lazyvim.json (currently 7 => fzf picker,
-- neo-tree explorer). Pin them so an upgrade cannot silently swap them.
vim.g.lazyvim_picker = "fzf"
vim.g.lazyvim_explorer = "snacks"

-- lang.python: basedpyright instead of pyright for type checking.
vim.g.lazyvim_python_lsp = "basedpyright"
