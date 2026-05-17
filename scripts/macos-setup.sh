#! /bin/sh
### -------------------------- Set macOS defaults -------------------------- ###
# https://github.com/mathiasbynens/dotfiles
# Back up macOS default settings before changing
now=$(date -u "+%Y-%m-%d-%H%M%s")
printf "Backing up defaults to %s.
macOS may request calendar or contacts permissions when reading defaults.
Some changes may require a restart to take effect.\n" \
  "$HOME/Desktop/macos-defaults-$now.txt"
defaults read >"$HOME/Desktop/macos-defaults-$now.txt"

###############################################################################
# General UI/UX                                                               #
###############################################################################

# Enable dark mode
defaults write NSGlobalDomain AppleInterfaceStyle -string "Dark"
defaults write NSGlobalDomain AppleAccentColor -string "-1"
defaults write NSGlobalDomain AppleHighlightColor -string \
  "0.847059 0.847059 0.862745 Graphite"

# Save to disk by default, instead of iCloud
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

# Set window dialog pop up speed to instant
defaults write -g NSWindowResizeTime -float 0.001

###############################################################################
# Peripherals                                                                 #
###############################################################################

# Trackpad: enable tap to click for this user and for the login screen
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# Disable automatic text substitution and autocorrect
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# Disable press-and-hold for keys in favor of key repeat
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# Increase key repeat rate
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# Natural scrolling: true = enabled (macOS default), false = traditional/inverted.
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool true

# Use keyboard navigation to move focus between controls (tab navigation)
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

###############################################################################
# Screen                                                                      #
###############################################################################

# Screensaver password requirement is owned by IT/MDM on this work Mac.

###############################################################################
# Finder                                                                      #
###############################################################################

# Set default location for new Finder windows
# Desktop: `PfDe`, `file://${HOME}/Desktop/`. For other paths: `PfLo`
defaults write com.apple.finder NewWindowTarget -string "PfHm"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/"

# Show icons for hard drives, servers, and removable media on the desktop
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowMountedServersOnDesktop -bool true
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true

# Finder: show hidden files by default
defaults write com.apple.finder AppleShowAllFiles -bool true

# Prefer Finder tabs: Dock -> Prefer tabs when opening documents
defaults write NSGlobalDomain AppleWindowTabbingMode -string "always"

# Finder: show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Finder: show status bar
defaults write com.apple.finder ShowStatusBar -bool true

# Finder: show path bar
defaults write com.apple.finder ShowPathbar -bool true

# Display full POSIX path as Finder window title
# defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

# Keep folders on top when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# When performing a search, search the current folder by default
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# Disable the warning when changing a file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# View files as list
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# Sort files by name in list view
# TODO

# Enable spring loading for directories
defaults write NSGlobalDomain com.apple.springing.enabled -bool true

# Avoid creating .DS_Store files on network or USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Show the ~/Library folder
chflags nohidden ~/Library

###############################################################################
# Menu bar, Dock, Dashboard, and hot corners                                  #
###############################################################################

# Change minimize/maximize window effect
defaults write com.apple.dock mineffect -string "genie"

# Minimize windows into their application’s icon
defaults write com.apple.dock minimize-to-application -bool true

# Enable spring loading for all Dock items
defaults write com.apple.dock enable-spring-load-actions-on-all-items -bool true

# Show indicator lights for open applications in the Dock
defaults write com.apple.dock show-process-indicators -bool true

# Wipe default macOS app icons from the Dock
# Useful for setting up new Macs. Optionally relaunch dock with `killall Dock`.
defaults write com.apple.dock persistent-apps -array

# Don’t animate opening applications from the Dock
defaults write com.apple.dock launchanim -bool false

# Speed up Mission Control animations
defaults write com.apple.dock expose-animation-duration -float 0.1

# Group windows by application in Mission Control
defaults write com.apple.dock expose-group-by-app -bool true

# Disable Dashboard
defaults write com.apple.dashboard mcx-disabled -bool true

# Don’t show Dashboard as a Space
defaults write com.apple.dock dashboard-in-overlay -bool true

# Don’t automatically rearrange Spaces based on most recent use
defaults write com.apple.dock mru-spaces -bool false

# Keep macOS default: activating an app switches to a Space that has its
# windows (rather than pulling the window onto the current Space).
defaults write NSGlobalDomain AppleSpacesSwitchOnActivate -bool true

# Make Dock icons of hidden applications translucent
defaults write com.apple.dock showhidden -bool true

# Don’t show recent applications in Dock
defaults write com.apple.dock show-recents -bool false

# Hot corners
# Possible values:
#  0: no-op
#  2: Mission Control
#  3: Show application windows
#  4: Desktop
#  5: Start screen saver
#  6: Disable screen saver
#  7: Dashboard
# 10: Put display to sleep
# 11: Launchpad
# 12: Notification Center
# 13: Lock screen
# Top right screen corner → Desktop
defaults write com.apple.dock wvous-tr-corner -int 0
defaults write com.apple.dock wvous-tr-modifier -int 0
# Bottom right screen corner → Mission Control
defaults write com.apple.dock wvous-br-corner -int 0
defaults write com.apple.dock wvous-br-modifier -int 0
# Bottom left screen corner
defaults write com.apple.dock wvous-bl-corner -int 0
defaults write com.apple.dock wvous-bl-modifier -int 0

# Apply Dock + Mission Control (Dock-side) changes this session and force
# the Dock to flush its in-memory copy of prefs so it can't overwrite us.
killall Dock 2>/dev/null || true

###############################################################################
# Networking                                                                  #
###############################################################################

# Configure network services
if networksetup -listallnetworkservices | grep -q "Ethernet"; then
  networksetup -setdhcp "Ethernet"
fi

###############################################################################
# TextEdit                                                                    #
###############################################################################

# Use plain text mode for new TextEdit documents
defaults write com.apple.TextEdit RichText -int 0

# Open and save files as UTF-8 in TextEdit
defaults write com.apple.TextEdit PlainTextEncoding -int 4
defaults write com.apple.TextEdit PlainTextEncodingForWrite -int 4

###############################################################################
# iTerm2 colortheme                                                           #
###############################################################################

# Import catppuccin-mocha colortheme from plist.
# After install: iTerm2 → Settings → Profiles → Colors → Color Presets… → catppuccin-mocha
defaults import com.googlecode.iterm2 "$HOME/scripts/iterm2.plist"

printf "\nDone. Some changes (Dock, Finder, menu bar) take effect after\nkillall Dock Finder cfprefsd, or a log out / log back in.\n"
