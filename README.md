# .dotfiles

Configuration files, managed with GNU Stow. Each top-level directory is
a stow package; its contents mirror `$HOME`.

| Package   | Links                  | Notes |
|-----------|------------------------|-------|
| `nvim`    | `~/.config/nvim`       | LazyVim. Usage guide: [`MANUAL.md`](nvim/.config/nvim/MANUAL.md) |
| `tmux`    | `~/.tmux.conf`         | Prefix `C-a`, OSC 52 clipboard |
| `ghostty` | `~/.config/ghostty`    | Kanagawa themes |
| `lazygit` | `~/.config/lazygit`    | |
| `mise`    | `~/.config/mise`       | Global tool versions |
| `tuicr`   | `~/.config/tuicr`      | |
| `git`     | `~/.gitconfig`         | No identity; see below |

## Install

```sh
git clone https://github.com/JamesC1305/.dotfiles ~/.dotfiles
mkdir -p ~/.config
cd ~/.dotfiles
stow nvim tmux lazygit mise tuicr git   # add ghostty where it is installed
```

Stow targets the parent of the directory it runs in, so the repository
must live at `~/.dotfiles`.

When a target directory does not exist, stow links the whole directory;
when it exists, stow links the entries inside it. Create `~/.config`
first so each package links its own directory inside it.

Name packages explicitly. Stow 1.x has no ignore list, so any file in a
package, including a README or `.gitignore`, is linked into `~`. Stow
2.x ignores those files and adds `--adopt`; prefer it where available.

## Git identity

`git/.gitconfig` holds no name, email or signing key. It includes
`~/.gitconfig.local`, which lives outside this repository:

```ini
[user]
	name = Your Name
	email = you@example.com
```

## Private configuration

Machine-specific configuration that should not be public lives in a
separate local repository, `~/.dotfiles-private`, and is stowed the
same way from there.
