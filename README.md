# dotfiles

Bootstrap script + opinionated configs for setting up a fresh work-mac development environment.
Forked from a personal setup ([handshou/dotfiles](https://github.com/handshou/dotfiles))
and trimmed: single identity, no yabai/skhd window manager, no FileVault/security
writes (left to IT), Catppuccin Mocha theming, vanilla neovim.

## Start Here

The intended flow is: **push this repo to your GitHub once, then run a single curl command on the fresh Mac**. Bootstrap installs everything else (Xcode CLT, Homebrew, all packages, dotfiles) from scratch.

### Step 1 — Push this repo to GitHub (one-time)

Create a new **public** repository at github.com named `dotfiles`. Public is required so the curl-bootstrap URL works without authentication. Then upload the contents of this folder. Easiest options:

- **From github.com directly** — on the new empty repo page, click *"uploading an existing file"*. In Finder, press `Cmd+Shift+.` to reveal hidden files, then drag everything from this folder (including `.zshrc`, `.gitconfig`, `.config/`, `.claude/`, etc.) into the browser drop zone. You may need to upload nested folders separately.
- **From a machine that has git** — AirDrop or copy the folder over, then:
  ```bash
  cd dotfiles
  git init && git add -A && git commit -m "Initial commit"
  git remote add origin git@github.com:<you>/dotfiles.git
  git branch -M main
  git push -u origin main
  ```

### Step 2 — Run bootstrap on the fresh Mac

Open Terminal.app and paste:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/<you>/dotfiles/HEAD/bootstrap.sh)"
```

Answer the three identity prompts (name, email, GitHub username) and then leave it alone for 10–20 minutes. When it finishes, follow the 5-step post-install checklist it prints.

### Optional — pre-set credentials to skip prompts

```bash
STRAP_GIT_NAME="Your Name" \
STRAP_GIT_EMAIL="you@example.com" \
STRAP_GITHUB_USER="your-github-username" \
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/<you>/dotfiles/HEAD/bootstrap.sh)"
```

### Optional — local-iteration mode (for editing this repo before pushing again)

Once you have git installed locally (after a first bootstrap, or on a machine where Xcode CLT is already there), you can re-run bootstrap from a local checkout instead of going through GitHub:

```bash
cd dotfiles
git init && git add -A && git commit -m "init"   # if not already a git repo
STRAP_DOTFILES_URL="$(pwd)" bash ./bootstrap.sh
```

## What the Script Does

1. Prompts for git identity (name, email, GitHub username) — single identity
2. Installs Homebrew
3. Generates an `ed25519` SSH key at `~/.ssh/id_ed25519` and writes `~/.ssh/config`
4. Installs packages from `Brewfile` (auto), then prompts for `Brewfile.work` and `Brewfile.optional`
5. Clones the dotfiles as a bare repo to `~/.cfg` and checks out into `$HOME`
6. Writes git identity to `~/.gitconfig` (after the checkout, so the values survive it)
7. Applies macOS defaults via `scripts/macos-setup.sh`
8. Sets a custom Alacritty icon (if `fileicon` is installed)
9. Installs `nvm`
10. Prints a 5-step post-install checklist

Things intentionally NOT done (compared to the upstream `handshou/dotfiles`):

- No FileVault enable or recovery-key dump (managed by IT)
- No screensaver-password / firewall / Safari security writes (managed by IT)
- No `Found this computer?` login-window message (IT may have its own)
- No yabai or skhd install or SIP-disable instructions
- No neovim plugin pre-install (no Lazy.nvim config bundled)
- No personal/work dual-identity SSH setup — single identity only

## Post-Install Checklist

After bootstrap completes the script prints these 5 steps:

1. **Add SSH key to GitHub** — `pbcopy < ~/.ssh/id_ed25519.pub`, paste at https://github.com/settings/ssh/new, test with `ssh -T git@github.com`, then switch the dotfiles remote: `config remote set-url origin git@github.com:<you>/dotfiles.git`
2. **Set up Alacritty** — `alacritty migrate`, and apply Catppuccin Mocha via iTerm2 → Settings → Profiles → Colors → Color Presets → `catppuccin-mocha`
3. **Install tmux plugins** — open tmux, hit `prefix + I` (Ctrl+a, then Shift+I) to install via TPM
4. **Install Node via nvm** — `source ~/.nvm/nvm.sh && nvm install --lts`
5. **Restart terminal** — close and reopen, or `source ~/.zshrc`

## The `config` Command

The bootstrap installs the dotfiles as a bare repo at `~/.cfg` with `$HOME` as the
work tree. Manage it via a `config` alias (added in `.bashrc`):

```bash
config status
config pull
config add <file>
config commit -m "message"
config push

# Switch remote to SSH (run after step 1 of the post-install checklist):
config remote set-url origin git@github.com:<you>/dotfiles.git
```

## macOS Defaults (`scripts/macos-setup.sh`)

Applies opinionated system preferences via `defaults write`. Backs up your
current defaults to `~/Desktop/macos-defaults-<timestamp>.txt` first.

| Section | Configures |
|:---|:---|
| UI/UX | Dark mode + graphite accent, save-to-disk default, instant window resize |
| Trackpad/Keyboard | Tap-to-click, fastest key repeat, full keyboard tab nav, autocorrect off |
| Finder | Hidden files visible, all extensions, list view, folders-first sort, no `.DS_Store` on network/USB |
| Dock & Mission Control | No recent apps, all 4 hot corners disabled, Dock icons of hidden apps translucent |
| Networking | Auto-DHCP for Ethernet |
| TextEdit | Plain text mode, UTF-8 |
| iTerm2 | Imports `catppuccin-mocha` colortheme |

Run manually after edits:
```bash
sh ~/scripts/macos-setup.sh
killall cfprefsd Dock Finder
```

## Brewfiles

Packages are split into three Brewfiles. Bootstrap installs `Brewfile` automatically
and prompts for the optional bundles.

| File | Description | Install |
|:-----|:------------|:--------|
| `Brewfile` | Core development tools and daily apps | Auto |
| `Brewfile.work` | Work-mac packages (Slack, Teams, MS Office, GCloud, Docker) | Prompted (default yes) |
| `Brewfile.optional` | Photography, media, games — personal stuff | Prompted (default no) |

### Core CLI (`Brewfile`)

| App | Description |
|:----|:------------|
| `neovim` | Editor (vanilla — no bundled config) |
| `deno`, `pnpm` | JS/TS runtimes (Node comes via `nvm`) |
| `python@3.11`, `python-tk` | Python |
| `rustup`, `goenv` | Language version managers |
| `tmux`, `tpm` | Terminal multiplexer + plugin manager |
| `ripgrep`, `fzf`, `tree`, `chafa`, `gh` | CLI utilities |
| `pgcli` | Postgres CLI |
| `stylua` | Lua formatter |

### Core GUI (`Brewfile`)

| App | Description |
|:----|:------------|
| `iterm2`, `alacritty` | Terminals |
| `firefox`, `zen` | Browsers |
| `alfred`, `obsidian`, `claude`, `claude-code` | Productivity / AI |
| `1password`, `1password-cli` | Password manager |
| `karabiner-elements` | Keyboard remapping (caps-lock → ctrl, plus vim-style hjkl arrows) |
| `font-jetbrains-mono-nerd-font` | Nerd font |
| `hiddenbar`, `stats` | Menu bar utilities |

### App Store (`Brewfile`, via `mas`)

| App | ID |
|:----|:---|
| Magnet | 441258766 |
| Dropover | 1355679052 |
| 1Password for Safari | 1569813296 |
| Keys for Safari | 1494642810 |
| Refined GitHub | 1519867270 |
| Wappalyzer | 1520333300 |

### Work (`Brewfile.work`)

| App | Description |
|:----|:------------|
| `docker`, `docker-compose` | Containers |
| `supabase` | Database tooling |
| `pulumi` | Infrastructure as code |
| `gcloud-cli` | Google Cloud CLI |
| `visual-studio-code` | Editor |
| `slack`, `microsoft-teams` | Work chat |
| `granola` | AI meeting notes |
| `microsoft-word`, `microsoft-excel`, `microsoft-powerpoint` | Office suite |
| `postman` | API testing |

### Optional (`Brewfile.optional`)

`rawtherapee`, `gimp`, `subler`, `transmission`, `love`, `hazel`, `discord`, `telegram`.
Skip during bootstrap (default), install later if wanted: `brew bundle --file=Brewfile.optional`.

## Theme

Catppuccin Mocha throughout:

- **Alacritty** — `.config/alacritty/themes/catppuccin_mocha.toml`, imported by `.alacritty.toml`
- **tmux** — `catppuccin/tmux` plugin loaded by TPM, flavor = `mocha`
- **iTerm2** — preset imported by `scripts/macos-setup.sh`; activate manually after install (see post-install step 2)
- **macOS** — system-level dark mode + graphite accent enabled by `macos-setup.sh`

## Karabiner

| Layer | Effect |
|:------|:-------|
| Caps Lock | Left Control (ergonomic remap) |
| Cmd + Esc | Cmd + \` (cycle windows within an app) |
| LeftCtrl + h/j/k/l | Left / Down / Up / Right arrow |
| LeftCtrl + d / u / s | Page Down / Page Up / Page Up |

Combined with the caps-lock remap, this effectively makes caps-lock a vim-style
navigation leader: caps + hjkl moves the cursor like arrow keys system-wide.

## Manual Installs

Apps not available via Homebrew (none currently in this setup — add here as needed).

## Caveats

- The `.bashrc` defines a zsh-flavored prompt (`%F{n}` color codes). It only renders correctly because `.zshrc` sources it into zsh — in actual bash you'd see literal `%F{243}` etc. Change the prompt in `.bashrc` if you ever invoke bash directly.
- `scripts/git-setup-work.sh` is now a no-op stub (kept for git-config-alias compatibility). Single identity only.
- The original repo committed `.config/karabiner/automatic_backups/` (~225 KB of historical snapshots). Harmless, but feel free to `rm -rf ~/.config/karabiner/automatic_backups/` after first run.
- `.config/yabai/yabairc` and `.config/skhd/skhdrc` are stubs. Delete the directories whenever you like.

## Changelog (this customization)

- Stripped personal/work dual-identity setup — single git identity only
- Removed yabai + skhd + SIP-disable instructions; Magnet handles window snapping
- Removed FileVault enable, screensaver/firewall/Safari security writes — IT-managed
- Stripped personal-leaning casks: ProtonVPN, Figma, Things 3, Vinegar/Baking Soda/DeArrow
- Removed Transmission and ProtonVPN defaults writes (orphaned by removed casks)
- Removed ClickUp from `Brewfile.work` (team-specific)
- Removed custom Spotlight ordering, Mail.app tweaks, hide-all-desktop-icons, Magnet hotkey wipe
- Removed Ctrl+1..9 → Desktop N hotkeys, analog menu-bar clock, auto-hide menu bar + Dock
- Swapped Tokyo Night Storm → Catppuccin Mocha (Alacritty, iTerm2, tmux)
- Fixed font inconsistency: Brewfile now installs JetBrains Mono Nerd Font (matching `bootstrap.sh` and the bundled `.ttf` fallback)
- Reordered bootstrap so `configure_git` runs after the bare-repo checkout (fixes a bug where the tracked `.gitconfig` would overwrite user-entered identity)
- Stripped `[user]` and `[github] user` from the tracked `.gitconfig` (bootstrap writes them at install time)
- Stripped `.config/nvim` submodule — vanilla nvim instead of inherited Lazy.nvim config
- Removed headless `:Lazy sync` and tree-sitter parser pre-compile from `bootstrap.sh`
- Removed dead `darktable` PATH entry and stale work-SSH-key reference from `.zshrc`
- Narrowed `tmux-sessionizer` search path to just `~/Developer`
- Fixed `.tmux-sessionizer` duplicate `tmux neww -n work` typo
- Fixed misleading "Disable natural scrolling" comment in `macos-setup.sh` (the value was always enabling it)
