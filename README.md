# oh-my-zsh-windows-config

One-time setup that gives **Git Bash on Windows** the same zsh + Oh My Zsh prompt as a Dev Container
(the `devcontainers` theme from the [common-utils feature](https://github.com/devcontainers/features/tree/main/src/common-utils)):

```
dtiDigital ➜ ~/source/my-repo (main) $
```

## Requirements

- Windows 10 1803+ / Windows 11 (uses the built-in `tar.exe`, which reads `.zst` packages)
- [Git for Windows](https://gitforwindows.org/) (`winget install --id Git.Git -e`)
- Internet access. Nothing else is taken from the machine.

## Install

From Git Bash, in one line (no clone needed; the script downloads everything it uses):

```bash
curl -fsSL https://raw.githubusercontent.com/eduardo-lima-dti/oh-my-zsh-windows-config/main/install.sh | bash
```

Options go before `bash`, e.g. `curl -fsSL <url> | OMZ_PLUGINS="git docker" bash`.

Or clone and run it:

```bash
git clone https://github.com/eduardo-lima-dti/oh-my-zsh-windows-config.git
bash oh-my-zsh-windows-config/install.sh
```

Or from PowerShell, after cloning:

```powershell
powershell -ExecutionPolicy Bypass -File .\oh-my-zsh-windows-config\install.ps1
```

If Git is installed for all users (`C:\Program Files\Git`), you get one UAC prompt: it is only used to unpack zsh into the Git folder.

Then open a new Git Bash window.

## What it does

Same steps as the Dev Containers feature, adapted to Git for Windows:

| Step | Dev Container feature | This script |
|---|---|---|
| zsh | `apt install zsh` | Latest MSYS2 `zsh` package from `repo.msys2.org`, unpacked into the Git root (skipped if zsh is already there) |
| Oh My Zsh | shallow `git clone` to `~/.oh-my-zsh` | Same command and flags (`core.autocrlf=false` keeps LF endings) |
| Theme | `devcontainers.zsh-theme` + `codespaces` alias | Downloaded from `devcontainers/features` into `~/.oh-my-zsh/custom/themes` |
| `~/.zshrc` | Oh My Zsh template, `ZSH_THEME="devcontainers"`, updates disabled | Same, plus `plugins=(git)` |
| Default shell | `chsh -s zsh` | A marked block in `~/.bashrc` runs `exec zsh` for interactive terminals |

It also adds `~/.oh-my-zsh/custom/git-bash.zsh`, which sets `$USER` (Git Bash leaves it empty; the theme's window-title hook uses it).

Re-running is safe. Any file that would change is first copied to `<file>.bak-<timestamp>`.

## Options

Set these as environment variables, e.g. `OMZ_PLUGINS="git docker" bash install.sh`.

| Variable | Default | Purpose |
|---|---|---|
| `OMZ_THEME` | `devcontainers` | Theme written to `~/.zshrc` |
| `OMZ_PLUGINS` | `git` | Plugins written to `~/.zshrc` |
| `DEVCONTAINERS_FEATURES_REF` | `main` | Branch, tag or commit of `devcontainers/features` the theme is taken from |
| `MSYS2_ZSH_PKG_URL` | latest | Use a specific MSYS2 zsh package |
| `SKIP_ZSH_INSTALL` / `FORCE_ZSH_INSTALL` | `0` | Skip, or force, the zsh install |
| `SKIP_BASHRC` | `0` | Leave `~/.bashrc` alone |

## Theme tips (from the devcontainers theme)

```bash
git config --global devcontainers-theme.show-dirty 1   # show ✗ when the repo has changes
git config devcontainers-theme.hide-status 1           # hide git status in a slow/large repo
```

## Uninstall

Remove the `oh-my-zsh-windows-config` block from `~/.bashrc`. Optionally delete `~/.oh-my-zsh` and `~/.zshrc`,
or restore the `.bak-*` copies.
