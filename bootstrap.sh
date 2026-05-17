#!/usr/bin/env bash
### ------------ bootstrap.sh - set up development environment ------------ ###
# Origin: https://github.com/MikeMcQuaid/strap, https://github.com/Homebrew/install
#
# Usage:
#   # Run from a remote repo (once you push your dotfiles to GitHub):
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/<you>/dotfiles/HEAD/bootstrap.sh)"
#
#   # Run from a local checkout (for iterating before pushing anywhere):
#   #   1. cd into the dotfiles directory
#   #   2. If it isn't already a git repo, run: git init && git add -A && git commit -m "init"
#   #   3. Then run:
#   #        STRAP_DOTFILES_URL="$(pwd)" bash ./bootstrap.sh
#   #      The bare-repo clone step accepts a local path as the URL.

set -e

OS=$(uname -s)
case $OS in
Darwin)
  export LINUX=0 MACOS=1 UNIX=1
  if [[ $(uname -m) == "arm64" ]]; then
    DEFAULT_HOMEBREW_PREFIX="/opt/homebrew"
  else
    DEFAULT_HOMEBREW_PREFIX="/usr/local"
  fi
  ;;
Linux)
  export LINUX=1 MACOS=0 UNIX=1
  if [[ -d $HOME/.linuxbrew ]]; then
    DEFAULT_HOMEBREW_PREFIX="$HOME/.linuxbrew"
  else
    DEFAULT_HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
  fi
  [[ $(id -un) == "codespace" ]] && export CODESPACE=1
  ;;
*) echo "Unsupported operating system $OS" && exit 1 ;;
esac
[[ -z $HOMEBREW_PREFIX ]] && HOMEBREW_PREFIX="$DEFAULT_HOMEBREW_PREFIX"

STRAP_CI=${STRAP_CI:=0}
STRAP_DEBUG=${STRAP_DEBUG:-0}
[[ $1 = "--debug" || -o xtrace ]] && STRAP_DEBUG=1
STRAP_INTERACTIVE=${STRAP_INTERACTIVE:-0}
STDIN_FILE_DESCRIPTOR=0
[ -t "$STDIN_FILE_DESCRIPTOR" ] && STRAP_INTERACTIVE=1
# Pre-populate from existing git config (for re-runs).
# Single identity only (work Mac); no personal/work split.
[ -z "$STRAP_GIT_NAME" ] && STRAP_GIT_NAME="$(git config --global user.name 2>/dev/null || true)"
[ -z "$STRAP_GIT_EMAIL" ] && STRAP_GIT_EMAIL="$(git config --global user.email 2>/dev/null || true)"
[ -z "$STRAP_GITHUB_USER" ] && STRAP_GITHUB_USER="$(git config --global github.user 2>/dev/null || true)"

# Interactive prompts for required variables (works on fresh macOS without gum)
prompt_if_missing() {
  local var_name="$1" prompt_text="$2" default_val="$3"
  local current_val="${!var_name}"
  if [ -z "$current_val" ]; then
    if [ "$STRAP_INTERACTIVE" -gt 0 ] 2>/dev/null || [ -t 0 ]; then
      if [ -n "$default_val" ]; then
        read -rp "--> $prompt_text [$default_val]: " input
        eval "$var_name=\"\${input:-$default_val}\""
      else
        read -rp "--> $prompt_text: " input
        eval "$var_name=\"\$input\""
      fi
    fi
  fi
}

prompt_if_missing STRAP_GIT_NAME "Enter your full name for git commits"
prompt_if_missing STRAP_GIT_EMAIL "Enter your email for git commits"
prompt_if_missing STRAP_GITHUB_USER "Enter your GitHub username"

STRAP_GIT_NAME=${STRAP_GIT_NAME:?Variable not set}
STRAP_GIT_EMAIL=${STRAP_GIT_EMAIL:?Variable not set}
STRAP_GITHUB_USER=${STRAP_GITHUB_USER:?Variable not set}
DEFAULT_DOTFILES_URL="https://github.com/$STRAP_GITHUB_USER/dotfiles"
STRAP_DOTFILES_URL=${STRAP_DOTFILES_URL:="$DEFAULT_DOTFILES_URL"}
STRAP_DOTFILES_BRANCH=${STRAP_DOTFILES_BRANCH:="main"}
STRAP_SUCCESS=""

sudo_askpass() {
  if [ -n "$SUDO_ASKPASS" ]; then
    sudo --askpass "$@"
  else
    sudo "$@"
  fi
}

cleanup() {
  set +e
  sudo_askpass rm -rf "$CLT_PLACEHOLDER" "$SUDO_ASKPASS" "$SUDO_ASKPASS_DIR"
  sudo --reset-timestamp
  if [ -z "$STRAP_SUCCESS" ]; then
    if [ -n "$STRAP_STEP" ]; then
      echo "!!! $STRAP_STEP FAILED" >&2
    else
      echo "!!! FAILED" >&2
    fi
    if [ "$STRAP_DEBUG" -eq 0 ]; then
      echo "!!! Run '$0 --debug' for debugging output." >&2
    fi
  fi
}
trap "cleanup" EXIT

if [ "$STRAP_DEBUG" -gt 0 ]; then
  set -x
else
  STRAP_QUIET_FLAG="-q"
  Q="$STRAP_QUIET_FLAG"
fi

# Prompt for sudo password and initialize (or reinitialize) sudo
sudo --reset-timestamp

clear_debug() {
  set +x
}
reset_debug() {
  if [ "$STRAP_DEBUG" -gt 0 ]; then
    set -x
  fi
}

sudo_init() {
  if [ "$STRAP_INTERACTIVE" -eq 0 ]; then return; fi
  # If TouchID for sudo is setup: use that instead.
  if grep -q pam_tid /etc/pam.d/sudo; then return; fi
  local SUDO_PASSWORD SUDO_PASSWORD_SCRIPT
  if ! sudo --validate --non-interactive &>/dev/null; then
    while true; do
      read -rsp "--> Enter your password (for sudo access):" SUDO_PASSWORD
      echo
      if sudo --validate --stdin 2>/dev/null <<<"$SUDO_PASSWORD"; then
        break
      fi
      unset SUDO_PASSWORD
      echo "!!! Wrong password!" >&2
    done
    clear_debug
    SUDO_PASSWORD_SCRIPT="$(
      cat <<-BASH
				#!/usr/bin/env bash
				echo "$SUDO_PASSWORD"
				BASH
    )"
    unset SUDO_PASSWORD
    SUDO_ASKPASS_DIR="$(mktemp -d)"
    SUDO_ASKPASS="$(mktemp "$SUDO_ASKPASS_DIR"/strap-askpass-XXXXXXXX)"
    chmod 700 "$SUDO_ASKPASS_DIR" "$SUDO_ASKPASS"
    bash -c "cat > '$SUDO_ASKPASS'" <<<"$SUDO_PASSWORD_SCRIPT"
    unset SUDO_PASSWORD_SCRIPT
    reset_debug
    export SUDO_ASKPASS
  fi
}

sudo_refresh() {
  clear_debug
  if [ -n "$SUDO_ASKPASS" ]; then
    sudo --askpass --validate
  else
    sudo_init
  fi
  reset_debug
}

abort() {
  STRAP_STEP=""
  echo "!!! $*" >&2
  exit 1
}
log() {
  STRAP_STEP="$*"
  sudo_refresh
  echo "--> $*"
}
logn() {
  STRAP_STEP="$*"
  sudo_refresh
  printf -- "--> %s " "$*"
}
logk() {
  STRAP_STEP=""
  echo "OK"
}
escape() {
  printf '%s' "${1//\'/\'}"
}

# Given a list of scripts in the dotfiles repo, run the first one that exists
run_dotfile_scripts() {
  if [ -d ~/.dotfiles ]; then
    (
      cd ~/.dotfiles
      for i in "$@"; do
        if [ -f "$i" ] && [ -x "$i" ]; then
          log "Running dotfiles $i:"
          if [ "$STRAP_DEBUG" -eq 0 ]; then
            "$i" 2>/dev/null
          else
            "$i"
          fi
          break
        fi
      done
    )
  fi
}

[ "$USER" = "root" ] && abort "Run bootstrap.sh as yourself, not root."

# shellcheck disable=SC2086
if [ "$MACOS" -gt 0 ]; then
  [ "$STRAP_CI" -eq 0 ] && caffeinate -s -w $$ &
  groups | grep $Q -E "\b(admin)\b" || abort "Add $USER to admin."
fi

# Security defaults (Safari Java, firewall, screensaver password, login-window
# message) and FileVault enablement intentionally omitted on this work Mac —
# these are owned by IT/MDM.

# Set up Xcode Command Line Tools
install_xcode_clt() {
  if ! [ -f "/Library/Developer/CommandLineTools/usr/bin/git" ]; then
    log "Installing the Xcode Command Line Tools:"
    CLT_STRING=".com.apple.dt.CommandLineTools.installondemand.in-progress"
    CLT_PLACEHOLDER="/tmp/$CLT_STRING"
    sudo_askpass touch "$CLT_PLACEHOLDER"
    CLT_PACKAGE=$(softwareupdate -l |
      grep -B 1 "Command Line Tools" |
      awk -F"*" '/^ *\*/ {print $2}' |
      sed -e 's/^ *Label: //' -e 's/^ *//' |
      sort -V |
      tail -n1)
    sudo_askpass softwareupdate -i "$CLT_PACKAGE"
    sudo_askpass rm -f "$CLT_PLACEHOLDER"
    if ! [ -f "/Library/Developer/CommandLineTools/usr/bin/git" ]; then
      if [ "$STRAP_INTERACTIVE" -gt 0 ]; then
        echo
        logn "Requesting user install of Xcode Command Line Tools:"
        xcode-select --install
      else
        echo
        abort "Install Xcode Command Line Tools with 'xcode-select --install'."
      fi
    fi
    logk
  fi
}

# shellcheck disable=SC2086
check_xcode_license() {
  if /usr/bin/xcrun clang 2>&1 | grep $Q license; then
    if [ "$STRAP_INTERACTIVE" -gt 0 ]; then
      logn "Asking for Xcode license confirmation:"
      sudo_askpass xcodebuild -license
      logk
    else
      abort "Run 'sudo xcodebuild -license' to agree to the Xcode license."
    fi
  fi
}

if [ "$MACOS" -gt 0 ]; then
  install_xcode_clt
  check_xcode_license
else
  log "Not macOS. Xcode CLT install and license check skipped."
fi

# Generate SSH key (single identity for this work Mac).
# https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent
if [ ! -f ~/.ssh/config ]; then
  log "Setting up SSH key and config"
  mkdir -p ~/.ssh
  chmod 700 ~/.ssh

  if [ ! -f ~/.ssh/id_ed25519 ]; then
    log "Generating SSH key"
    yes "y" | ssh-keygen -t ed25519 -C "$STRAP_GIT_EMAIL" -f ~/.ssh/id_ed25519 -N ""
    ssh-add ~/.ssh/id_ed25519
  fi

  log "Creating SSH config"
  cat > ~/.ssh/config << 'EOF'
Host github.com
    HostName github.com
    User git
    AddKeysToAgent yes
    UseKeychain yes
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
EOF
  chmod 600 ~/.ssh/config
fi

configure_git() {
  logn "Configuring Git:"
  if [ "$STRAP_CI" -gt 0 ]; then
    git config --global commit.gpgsign false
    git config --global gpg.format openpgp
  fi
  if [ -n "$STRAP_GIT_NAME" ] && ! git config user.name >/dev/null; then
    git config --global user.name "$STRAP_GIT_NAME"
  fi
  if [ -n "$STRAP_GIT_EMAIL" ] && ! git config user.email >/dev/null; then
    git config --global user.email "$STRAP_GIT_EMAIL"
  fi
  if [ -n "$STRAP_GITHUB_USER" ] &&
    [ "$(git config github.user)" != "$STRAP_GITHUB_USER" ]; then
    git config --global github.user "$STRAP_GITHUB_USER"
  fi
  # SSH commit signing (non-CI). Reuses ~/.ssh/id_ed25519 — no GPG needed.
  # NOTE: GitHub will only show the "Verified" badge once the same public
  # key is also registered as a Signing Key (separate role from Auth Key)
  # at https://github.com/settings/ssh/new
  if [ "$STRAP_CI" -eq 0 ] && [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
    [ -z "$(git config --global gpg.format)" ] && git config --global gpg.format ssh
    [ -z "$(git config --global user.signingkey)" ] && git config --global user.signingkey "$HOME/.ssh/id_ed25519.pub"
    [ -z "$(git config --global commit.gpgsign)" ] && git config --global commit.gpgsign true
    [ -z "$(git config --global tag.gpgsign)" ] && git config --global tag.gpgsign true
  fi
  # Set up GitHub HTTPS credentials
  # shellcheck disable=SC2086
  if git credential-osxkeychain 2>&1 | grep $Q "git.credential-osxkeychain"; then
    # Execute credential in case it's a wrapper script for credential-osxkeychain
    if git "credential-$(git config --global credential.helper 2>/dev/null)" 2>&1 |
      grep -v $Q "git.credential-osxkeychain"; then
      git config --global credential.helper osxkeychain
    fi
    if [ -n "$STRAP_GITHUB_USER" ] && [ -n "$STRAP_GITHUB_TOKEN" ]; then
      PROTOCOL="protocol=https\\nhost=github.com"
      printf "%s\\n" "$PROTOCOL" | git credential reject
      printf "%s\\nusername=%s\\npassword=%s\\n" \
        "$PROTOCOL" "$STRAP_GITHUB_USER" "$STRAP_GITHUB_TOKEN" |
        git credential approve
    else
      log "Skipping Git credential setup."
    fi
    logk
  fi
}

# NOTE: configure_git is invoked AFTER the bare-repo checkout (see below),
# so the user identity it writes survives the checkout. If we called it here,
# the bare-repo checkout would overwrite ~/.gitconfig and any identity values
# we set would be lost.

# Check for and install any remaining software updates
logn "Checking for software updates:"
# shellcheck disable=SC2086
if softwareupdate -l 2>&1 | grep $Q "No new software available."; then
  logk
else
  if [ "$MACOS" -gt 0 ] && [ "$STRAP_CI" -eq 0 ]; then
    echo
    log "Installing software updates:"
    sudo_askpass softwareupdate --install --all
    check_xcode_license
  else
    log "Skipping software updates."
  fi
  logk
fi

# shellcheck disable=SC2086
install_homebrew() {
  logn "Installing Homebrew:"
  HOMEBREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
  [ -n "$HOMEBREW_PREFIX" ] || HOMEBREW_PREFIX="$DEFAULT_HOMEBREW_PREFIX"
  [ -d "$HOMEBREW_PREFIX" ] || sudo_askpass mkdir -p "$HOMEBREW_PREFIX"
  if [ "$MACOS" -gt 0 ]; then
    sudo_askpass chown "root:wheel" "$HOMEBREW_PREFIX" 2>/dev/null || true
  else
    sudo_askpass chown "root:root" "$HOMEBREW_PREFIX" 2>/dev/null || true
  fi
  (
    cd "$HOMEBREW_PREFIX"
    sudo_askpass mkdir -p \
      Cellar Caskroom Frameworks bin etc include lib opt sbin share var
    if [ "$MACOS" -gt 0 ]; then
      sudo_askpass chown "$USER:admin" \
        Cellar Caskroom Frameworks bin etc include lib opt sbin share var
    else
      sudo_askpass chown "$USER:$USER" \
        Cellar Caskroom Frameworks bin etc include lib opt sbin share var
    fi
  )
  HOMEBREW_REPOSITORY="$(brew --repository 2>/dev/null || true)"
  [ -n "$HOMEBREW_REPOSITORY" ] || HOMEBREW_REPOSITORY="$HOMEBREW_PREFIX/Homebrew"
  [ -d "$HOMEBREW_REPOSITORY" ] || sudo_askpass mkdir -p "$HOMEBREW_REPOSITORY"
  if [ "$MACOS" -gt 0 ]; then
    sudo_askpass chown -R "$USER:admin" "$HOMEBREW_REPOSITORY"
  else
    sudo_askpass chown -R "$USER:$USER" "$HOMEBREW_REPOSITORY"
  fi
  if [ "$HOMEBREW_PREFIX" != "$HOMEBREW_REPOSITORY" ]; then
    ln -sf "$HOMEBREW_REPOSITORY/bin/brew" "$HOMEBREW_PREFIX/bin/brew"
  fi
  export GIT_DIR="$HOMEBREW_REPOSITORY/.git" GIT_WORK_TREE="$HOMEBREW_REPOSITORY"
  git init $Q
  git config remote.origin.url "https://github.com/Homebrew/brew"
  git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
  git fetch $Q --tags --force
  git reset $Q --hard origin/HEAD
  unset GIT_DIR GIT_WORK_TREE
  logk
  export PATH="$HOMEBREW_PREFIX/bin:$PATH"
  logn "Updating Homebrew:"
  brew update
  logk
}

set_up_brew_skips() {
  local brewfile_path casks ci_skips mas_ids mas_prefix
  log "Setting up Homebrew Bundle formula installs to skip."
  ci_skips="awscli black jupyterlab mkvtoolnix zsh-completions"
  [ "$STRAP_CI" -gt 0 ] && HOMEBREW_BUNDLE_BREW_SKIP="$ci_skips"
  if [ -f "$HOME/.Brewfile" ]; then
    brewfile_path="$HOME/.Brewfile"
  elif [ -f "Brewfile" ]; then
    brewfile_path="Brewfile"
  else
    abort "No Brewfile found"
  fi
  log "Setting up Homebrew Bundle cask installs to skip."
  if [ "$MACOS" -gt 0 ] && [ "$brewfile_path" == "$HOME/.Brewfile" ]; then
    casks="$(brew bundle list --global --cask --quiet | tr '\n' ' ')"
  elif [ "$MACOS" -gt 0 ] && [ "$brewfile_path" == "Brewfile" ]; then
    casks="$(brew bundle list --cask --quiet | tr '\n' ' ')"
  else
    log "Cask commands are only supported on macOS."
  fi
  HOMEBREW_BUNDLE_CASK_SKIP="${casks%% }"
  log "Setting up Homebrew Bundle Mac App Store (mas) installs to skip."
  mas_ids=""
  mas_prefix='*mas*, id: '
  while read -r brewfile_line; do
    # shellcheck disable=SC2295
    [[ $brewfile_line == *$mas_prefix* ]] && mas_ids+="${brewfile_line##$mas_prefix} "
  done <"$brewfile_path"
  HOMEBREW_BUNDLE_MAS_SKIP="${mas_ids%% }"
  log "HOMEBREW_BUNDLE_BREW_SKIP='$HOMEBREW_BUNDLE_BREW_SKIP'"
  log "HOMEBREW_BUNDLE_CASK_SKIP='$HOMEBREW_BUNDLE_CASK_SKIP'"
  log "HOMEBREW_BUNDLE_MAS_SKIP='$HOMEBREW_BUNDLE_MAS_SKIP'"
  export HOMEBREW_BUNDLE_BREW_SKIP="$HOMEBREW_BUNDLE_BREW_SKIP"
  export HOMEBREW_BUNDLE_CASK_SKIP="$HOMEBREW_BUNDLE_CASK_SKIP"
  export HOMEBREW_BUNDLE_MAS_SKIP="$HOMEBREW_BUNDLE_MAS_SKIP"
}

run_brew_installs() {
  local brewfile_domain brewfile_path brewfile_url git_branch github_user
  if ! command -v brew &>/dev/null; then
    log "brew command not in shell environment. Attempting to load."
    eval "$("$HOMEBREW_PREFIX"/bin/brew shellenv)"
    command -v brew &>/dev/null && logk || return 1
  fi
  # Disable Homebrew Google Analytics: https://docs.brew.sh/Analytics
  brew analytics off
  [ "$STRAP_CI" -gt 0 ] || [ "$LINUX" -gt 0 ] && set_up_brew_skips
  [ "$LINUX" -gt 0 ] && brew install gcc # "We recommend that you install GCC"
  log "Running Homebrew installs."
  if [ -f "$HOME/.Brewfile" ]; then
    log "Installing from $HOME/.Brewfile with Brew Bundle."
    brew bundle check --global || brew bundle --global
    logk
  elif [ -f "Brewfile" ]; then
    log "Installing from local Brewfile with Brew Bundle."
    brew bundle check || brew bundle
    logk
  else
    [ -z "$STRAP_DOTFILES_BRANCH" ] && STRAP_DOTFILES_BRANCH=HEAD
    git_branch="${STRAP_DOTFILES_BRANCH##*/}"
    github_user="${STRAP_GITHUB_USER:?Variable not set}"
    brewfile_domain="https://raw.githubusercontent.com"
    brewfile_path="$github_user/dotfiles/$git_branch/Brewfile"
    brewfile_url="$brewfile_domain/$brewfile_path"
    log "Installing from $brewfile_url with Brew Bundle."
    curl -fsSL "$brewfile_url" | brew bundle --file=-
    logk
  fi
  # Tap a custom Homebrew tap
  if [ -n "$CUSTOM_HOMEBREW_TAP" ]; then
    read -ra CUSTOM_HOMEBREW_TAP <<<"$CUSTOM_HOMEBREW_TAP"
    log "Running 'brew tap ${CUSTOM_HOMEBREW_TAP[*]}':"
    brew tap "${CUSTOM_HOMEBREW_TAP[@]}"
    logk
  fi
  # Run a custom Brew command
  if [ -n "$CUSTOM_BREW_COMMAND" ]; then
    log "Executing 'brew $CUSTOM_BREW_COMMAND':"
    # shellcheck disable=SC2086
    brew $CUSTOM_BREW_COMMAND
    logk
  fi
}

# Install Homebrew early (needed for gum TUI and other tools)
# https://docs.brew.sh/Installation
script_url="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
NONINTERACTIVE=$STRAP_CI \
  /usr/bin/env bash -c "$(curl -fsSL $script_url)" || install_homebrew

# Set up Homebrew on Linux: https://docs.brew.sh/Homebrew-on-Linux
# [ "$LINUX" -gt 0 ] && run_dotfile_scripts scripts/linuxbrew.sh

run_brew_installs || abort "Homebrew installs were not successful."

# Optional Brewfile installs (interactive prompts)
install_optional_brewfile() {
  local brewfile_name="$1" description="$2" default="${3:-n}"
  local brewfile_path="$HOME/$brewfile_name"

  # Check if Brewfile exists locally or in repo
  if [ ! -f "$brewfile_path" ]; then
    # Try to fetch from repo
    local brewfile_url="https://raw.githubusercontent.com/$STRAP_GITHUB_USER/dotfiles/$STRAP_DOTFILES_BRANCH/$brewfile_name"
    if curl --output /dev/null --silent --head --fail "$brewfile_url"; then
      log "Fetching $brewfile_name from repo..."
      curl -fsSL "$brewfile_url" -o "$brewfile_path"
    else
      return 0  # Brewfile doesn't exist, skip silently
    fi
  fi

  if [ "$STRAP_INTERACTIVE" -gt 0 ] && [ -t 0 ]; then
    local prompt_default
    [ "$default" = "y" ] && prompt_default="Y/n" || prompt_default="y/N"
    read -rp "--> Install $description? [$prompt_default]: " response
    response="${response:-$default}"
    case "$response" in
      [Yy]*)
        log "Installing $description from $brewfile_name"
        brew bundle --file="$brewfile_path"
        logk
        ;;
      *)
        log "Skipping $description"
        ;;
    esac
  fi
}

# Prompt for optional package installs
if [ "$STRAP_INTERACTIVE" -gt 0 ]; then
  echo ""
  echo "--> Optional package bundles:"
  install_optional_brewfile "Brewfile.work" "work packages (Slack, MS Office, Figma, GCloud)" "y"
  install_optional_brewfile "Brewfile.optional" "optional packages (photography, media, games)" "n"
fi

# Dotfiles are set up via bare repo method below (lines 664+)
# Old clone-and-copy method removed - it conflicted with bare repo checkout
## strap_dotfiles_branch_name="${STRAP_DOTFILES_BRANCH##*/}"
## log "Checking out $strap_dotfiles_branch_name in ~/.dotfiles."
# shellcheck disable=SC2086
##(
##  cd ~/.dotfiles
##  git stash
##  git fetch $Q
##  git checkout "$strap_dotfiles_branch_name"
##  git pull $Q --rebase --autostash
##)

# Check if the font is installed in the specified directory
FONT_NAME="JetBrainsMonoNerdFont-Regular"
FONT_DIR="$HOME/Library/Fonts"
FONT_FILE="$HOME/JetBrainsMonoNerdFont-Regular.ttf"
if ls "$FONT_DIR" 2>/dev/null | grep -i "$FONT_NAME" | grep -i ".ttf\|.otf" >/dev/null; then
    log "Font '$FONT_NAME' is already installed."
elif command -v brew &>/dev/null; then
    log "Installing font via Homebrew..."
    brew install --cask font-jetbrains-mono-nerd-font
elif [ -f "$FONT_FILE" ]; then
    log "Installing font '$FONT_NAME' by copying to ~/Library/Fonts..."
    mkdir -p "$FONT_DIR"
    cp "$FONT_FILE" "$FONT_DIR/"
else
    log "Font '$FONT_NAME' not found. Please install manually."
fi

logk

if [ ! -d "$HOME/.cfg" ]; then
  if [ -z "$STRAP_DOTFILES_URL" ] || [ -z "$STRAP_DOTFILES_BRANCH" ]; then
    abort "Please set STRAP_DOTFILES_URL and STRAP_DOTFILES_BRANCH."
  fi
  log "Cloning $STRAP_DOTFILES_URL bare to ~/.cfg."
  git clone $Q --bare "$STRAP_DOTFILES_URL" $HOME/.cfg
  function config {
    /usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME "$@"
  }
  mkdir -p .config-backup
  if config checkout 2>/dev/null; then
    log "Checked out config."
  else
    log "Backing up pre-existing files."
    # Extract filenames from git error output (lines starting with whitespace, containing paths)
    config checkout 2>&1 | grep -E "^\s+" | grep -v "^error:" | grep -v "Please move" | grep -v "Aborting" | awk '{$1=$1};1' | while read -r f; do
      if [ -n "$f" ] && [ -e "$f" ]; then
        mkdir -p ".config-backup/$(dirname "$f")"
        mv "$f" ".config-backup/$f" 2>/dev/null || true
      fi
    done
    config checkout
  fi
  config config --local status.showUntrackedFiles no
  # (No submodules currently — nvim is vanilla.)
fi

# Write git identity now that the bare-repo checkout has placed the tracked
# .gitconfig (structural settings only) at ~/.gitconfig. configure_git appends
# user.name/email/signingkey and github.user via `git config --global`.
configure_git

# Apply macOS defaults (dock, Finder, hotkeys, etc.). Runs post-Brewfile so
# app-specific defaults (Transmission, ProtonVPN, iTerm2 theme) resolve
# against installed apps. Backs current defaults up to ~/Desktop first.
if [ "$MACOS" -gt 0 ] && [ -x "$HOME/scripts/macos-setup.sh" ]; then
  log "Applying macOS defaults (scripts/macos-setup.sh)"
  "$HOME/scripts/macos-setup.sh" || log "macos-setup.sh exited non-zero (continuing)"
fi

# (Removed: headless :Lazy sync and tree-sitter parser pre-compile. They only
# made sense with handshou's nvim config submodule. With vanilla nvim, do your
# own plugin setup later.)

# Install nvm: https://github.com/nvm-sh/nvm
log "Installing node version manager (nvm)"

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/HEAD/install.sh | bash

STRAP_SUCCESS=1
log "Your system is now bootstrapped!"

echo ""
echo "=============================================="
echo "  POST-INSTALL CHECKLIST"
echo "=============================================="
echo ""
echo "  1. ADD SSH KEY TO GITHUB"
echo "  ────────────────────────"
echo ""
echo "     GitHub account ($STRAP_GITHUB_USER):"
echo ""
echo "     Step 1: Copy your public key to clipboard:"
echo "       pbcopy < ~/.ssh/id_ed25519.pub"
echo ""
echo "     Step 2: Open in browser:"
echo "       https://github.com/settings/ssh/new"
echo ""
echo "     Step 3: Paste key, give it a name, click 'Add SSH key'"
echo ""
echo "     Step 4: Test connection:"
echo "       ssh -T git@github.com"
echo "       # Success: 'Hi $STRAP_GITHUB_USER! You've successfully authenticated...'"
echo ""
echo "     Step 5: Switch dotfiles remote from HTTPS to SSH (so 'config push' works):"
echo "       config remote set-url origin git@github.com:$STRAP_GITHUB_USER/dotfiles.git"
echo "       config remote -v   # verify it now shows git@github.com"
echo ""
echo "  2. APPLY CATPPUCCIN MOCHA THEME IN iTERM2"
echo "  ─────────────────────────────────────────"
echo ""
echo "     iTerm2 → Settings → Profiles → Colors → Color Presets → catppuccin-mocha"
echo ""
echo "  3. INSTALL TMUX PLUGINS"
echo "  ───────────────────────"
echo ""
echo "     Step 1: Open tmux:"
echo "       tmux"
echo ""
echo "     Step 2: Press prefix + I to install plugins:"
echo "       Ctrl+a, then Shift+I"
echo ""
echo "     Step 3: Wait for 'TMUX environment reloaded' message"
echo ""
echo "     Step 4: If status bar colors look wrong, install Homebrew bash so"
echo "             status-bar plugins have a modern shell on PATH:"
echo "       brew install bash && tmux kill-server && tmux"
echo ""
echo "  4. INSTALL NODE.JS VIA NVM"
echo "  ──────────────────────────"
echo ""
echo "     source ~/.nvm/nvm.sh && nvm install --lts"
echo ""
echo "  5. RESTART TERMINAL"
echo "  ───────────────────"
echo ""
echo "     Close and reopen Terminal, or run:"
echo "       source ~/.zshrc"
echo ""
echo "=============================================="
