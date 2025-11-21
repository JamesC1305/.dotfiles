# .dotfiles

Dotfiles are managed via GNU stow. In order to correctly symlink config files, ensure all necessary directories are already created (e.g. ~/.config already exists). To insert the config files, run `stow <config folder>`, e.g. `stow nvim`. 
