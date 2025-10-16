#!/bin/bash

# Ask for the administrator password upfront
sudo -v

# Keep-alive: update existing `sudo` time stamp until `.osx` has finished
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

symlink_dotfiles() {
  echo "Symlinking all dotfiles..."
  mkdir -p "$HOME/.dotfiles-backup"

  # Find all files within the home/ directory, excluding .DS_Store
  find "home" -type f -not -name ".DS_Store" | while read -r source_file; do
    # Remove the 'home/' prefix to get the relative path
    relative_path="${source_file#home/}"
    target_file="$HOME/$relative_path"

    # Backup existing file if it's not a symlink
    if [ -e "$target_file" ] && [ ! -L "$target_file" ]; then
      echo "Backing up existing $target_file"
      # Ensure backup directory exists
      mkdir -p "$(dirname "$HOME/.dotfiles-backup/$relative_path")"
      mv "$target_file" "$HOME/.dotfiles-backup/$relative_path"
    fi

    # Create parent directory for the symlink if it doesn't exist
    mkdir -p "$(dirname "$target_file")"

    # Create the symlink
    echo "Symlinking $source_file to $target_file"
    ln -sf "$(pwd)/$source_file" "$target_file"
  done
}

# Set computer name (as done via System Preferences → Sharing)
sudo scutil --set ComputerName "ATTD-Zen4"
sudo scutil --set HostName "ATTD-Zen4"
sudo scutil --set LocalHostName "ATTD-Zen4"
sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string "ATTD-Zen4"

echo "Enable full keyboard access for all controls (e.g. enable Tab in modal dialogs)"
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

echo "Enable subpixel font rendering on non-Apple LCDs"
defaults write NSGlobalDomain AppleFontSmoothing -int 2

# Show remaining battery time; hide percentage
# defaults write com.apple.menuextra.battery ShowPercent -string "NO"
# defaults write com.apple.menuextra.battery ShowTime -string "YES"

# Always show scrollbars
# defaults write NSGlobalDomain AppleShowScrollBars -string "Always"
# Possible values: `WhenScrolling`, `Automatic` and `Always`

###############################################################################
# Finder                                                                      #
###############################################################################

# echo "Allow quitting Finder via ⌘ + Q; doing so will also hide desktop icons"
# defaults write com.apple.finder QuitMenuItem -bool true

# Disable window animations and Get Info animations in Finder
# defaults write com.apple.finder DisableAllAnimations -bool true

echo "Show all filename extensions in Finder"
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

echo "Use current directory as default search scope in Finder"
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

echo "Show Path bar in Finder"
defaults write com.apple.finder ShowPathbar -bool true

echo "Show Status bar in Finder"
defaults write com.apple.finder ShowStatusBar -bool true

# Set User's home as the default location for new Finder windows
# For other paths, use `PfLo` and `file:///full/path/here/`
defaults write com.apple.finder NewWindowTarget -string "PfLo"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/"

# Show icons for hard drives, servers, and removable media on the desktop
# defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
# defaults write com.apple.finder ShowHardDrivesOnDesktop -bool false
# defaults write com.apple.finder ShowMountedServersOnDesktop -bool false
# defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true

# Finder: show hidden files by default
# defaults write com.apple.finder AppleShowAllFiles -bool true

# Finder: allow text selection in Quick Look
#defaults write com.apple.finder QLEnableTextSelection -bool true

# Expand save panel by default
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

# Expand print panel by default
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

# Save to disk (not to iCloud) by default
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

# Automatically quit printer app once the print jobs complete
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true

# Reveal IP address, hostname, OS version, etc. when clicking the clock
# in the login window
# sudo defaults write /Library/Preferences/com.apple.loginwindow AdminHostInfo HostName

#Disable the “Are you sure you want to open this application?” dialog
defaults write com.apple.LaunchServices LSQuarantine -bool false

###############################################################################
# Screen                                                                      #
###############################################################################

# Save screenshots to location
#defaults write com.apple.screencapture location -string "${HOME}/Desktop"
defaults write com.apple.screencapture location ~/Pictures/Screenshots

# Save screenshots in PNG format (other options: BMP, GIF, JPG, PDF, TIFF)
defaults write com.apple.screencapture type -string "png"

# Disable shadow in screenshots
# defaults write com.apple.screencapture disable-shadow -bool true

# Enable highlight hover effect for the grid view of a stack (Dock)
# defaults write com.apple.dock mouse-over-hilte-stack -bool true

# Enable spring loading for all Dock items
# defaults write enable-spring-load-actions-on-all-items -bool true

#Display ASCII control characters using caret notation in standard text views
# Try e.g. `cd /tmp; unidecode "\x{0000}" > cc.txt; open -e cc.txt`
defaults write NSGlobalDomain NSTextShowsControlCharacters -bool true

# Set language and text formats
# Note: if you’re in the US, replace `EUR` with `USD`, `Centimeters` with
# `Inches`, `en_GB` with `en_US`, and `true` with `false`.
#defaults write NSGlobalDomain AppleLanguages -array "en" "nl"
#defaults write NSGlobalDomain AppleLocale -string "en_GB@currency=EUR"
defaults write NSGlobalDomain AppleMeasurementUnits -string "Centimeters"
defaults write NSGlobalDomain AppleMetricUnits -bool true

# Disable press-and-hold for keys in favor of key repeat
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# Set a blazingly fast keyboard repeat rate
# Set a shorter Delay until key repeat
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# Disable auto-correct
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# Disable AirDrop
defaults write com.apple.NetworkBrowser DisableAirDrop -bool true

# Disable disk image verification
defaults write com.apple.frameworks.diskimages skip-verify -bool true
defaults write com.apple.frameworks.diskimages skip-verify-locked -bool true
defaults write com.apple.frameworks.diskimages skip-verify-remote -bool true

# Display full POSIX path as Finder window title
# defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

# Increase window resize speed for Cocoa applications
# defaults write NSGlobalDomain NSWindowResizeTime -float 0.001

# Avoid creating .DS_Store files on network volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

# Disable the warning when changing a file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Enable snap-to-grid for icons on the desktop and in other icon views
echo "Enable snap-to-grid for desktop icons"
/usr/libexec/PlistBuddy -c "Set :DesktopViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist
/usr/libexec/PlistBuddy -c "Set :FK_StandardViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist
/usr/libexec/PlistBuddy -c "Set :StandardViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist

# Use list view in all Finder windows by default
# Four-letter codes for the other view modes: `icnv`, `clmv`, `Flwv`
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# echo "Disable the warning before emptying the Trash"
defaults write com.apple.finder WarnOnEmptyTrash -bool false

# Restart automatically if the computer freezes
# sudo systemsetup -setrestartfreeze on

# Never go into computer sleep mode
# sudo systemsetup -setcomputersleep Off > /dev/null

# Check for software updates daily, not just once per week
# defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1

# Disable smart quotes as they’re annoying when typing code
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false

# Disable smart dashes as they’re annoying when typing code
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# echo "Require password immediately after sleep or screen saver begins"
# defaults write com.apple.screensaver askForPassword -int 1
# defaults write com.apple.screensaver askForPasswordDelay -int 0

###############################################################################
# Trackpad, mouse, keyboard, Bluetooth accessories, and input                 #
###############################################################################

echo "Enable tap to click (Trackpad)"
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# Disable “natural” (Lion-style) scrolling
# defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false

# Use scroll gesture with the Ctrl (^) modifier key to zoom
# defaults write com.apple.universalaccess closeViewScrollWheelToggle -bool true
# defaults write com.apple.universalaccess HIDScrollZoomModifierMask -int 262144
# Follow the keyboard focus while zoomed in
# defaults write com.apple.universalaccess closeViewZoomFollowsFocus -bool true

echo "Disable the “reopen windows when logging back in” option"
# This works, although the checkbox will still appear to be checked.
defaults write com.apple.loginwindow TALLogoutSavesState -bool false
defaults write com.apple.loginwindow LoginwindowLaunchesRelaunchApps -bool false

# Reset Launchpad, but keep the desktop wallpaper intact
# find "${HOME}/Library/Application Support/Dock" -name "*-*.db" -maxdepth 1 -delete

###############################################################################
# SSD-specific tweaks                                                         #
###############################################################################

# Disable local Time Machine snapshots
# sudo tmutil disablelocal

# Disable hibernation (speeds up entering sleep mode)
# sudo pmset -a hibernatemode 0

# Remove the sleep image file to save disk space
# sudo rm /Private/var/vm/sleepimage
# Create a zero-byte file instead…
# sudo touch /Private/var/vm/sleepimage
# And make sure it can’t be rewritten
# sudo chflags uchg /Private/var/vm/sleepimage

# Expand the following File Info panes:
# “General”, “Open with”, and “Sharing & Permissions”
defaults write com.apple.finder FXInfoPanesExpanded -dict \
	General -bool true \
	OpenWith -bool true \
	Privileges -bool true

###############################################################################
# Dock, Dashboard, and hot corners                                            #
###############################################################################

# Automatically hide and show the Dock
defaults write com.apple.dock autohide -bool true

# Enable highlight hover effect for the grid view of a stack (Dock)
# defaults write com.apple.dock mouse-over-hilite-stack -bool true

# Set the icon size of Dock items to 36 pixels. Dock size.
defaults write com.apple.dock tilesize -int 36

# Change minimize/maximize window effect
defaults write com.apple.dock mineffect -string "scale"

# Minimize windows into their application’s icon
defaults write com.apple.dock minimize-to-application -bool true

# Enable spring loading for all Dock items
defaults write com.apple.dock enable-spring-load-actions-on-all-items -bool true

# Show indicator lights for open applications in the Dock
defaults write com.apple.dock show-process-indicators -bool true

# Wipe all (default) app icons from the Dock
# This is only really useful when setting up a new Mac, or if you don’t use
# the Dock to launch apps.
#defaults write com.apple.dock persistent-apps -array

# Don’t animate opening applications from the Dock
#defaults write com.apple.dock launchanim -bool false

# Speed up Mission Control animations
defaults write com.apple.dock expose-animation-duration -float 0.2

defaults write com.apple.dock springboard-show-duration -float 0.2
defaults write com.apple.dock springboard-hide-duration -float 0.2

# Don’t automatically rearrange Spaces based on most recent use
defaults write com.apple.dock mru-spaces -bool false

# ###############################################################################
# # Safari & WebKit                                                             #
# ###############################################################################

# # Privacy: don’t send search queries to Apple
# defaults write com.apple.Safari UniversalSearchEnabled -bool false
# defaults write com.apple.Safari SuppressSearchSuggestions -bool true

# # Press Tab to highlight each item on a web page
# defaults write com.apple.Safari WebKitTabToLinksPreferenceKey -bool true
# defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2TabsToLinks -bool true

# # Show the full URL in the address bar (note: this still hides the scheme)
# defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true

# # Set Safari’s home page to `about:blank` for faster loading
# defaults write com.apple.Safari HomePage -string "about:blank"

# # Prevent Safari from opening ‘safe’ files automatically after downloading
# defaults write com.apple.Safari AutoOpenSafeDownloads -bool false

# # Allow hitting the Backspace key to go to the previous page in history
# defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2BackspaceKeyNavigationEnabled -bool true

# # Hide Safari’s bookmarks bar by default
# defaults write com.apple.Safari ShowFavoritesBar -bool false

# # Hide Safari’s sidebar in Top Sites
# defaults write com.apple.Safari ShowSidebarInTopSites -bool false

# # Disable Safari’s thumbnail cache for History and Top Sites
# defaults write com.apple.Safari DebugSnapshotsUpdatePolicy -int 2

# # Enable Safari’s debug menu
# defaults write com.apple.Safari IncludeInternalDebugMenu -bool true

# # Make Safari’s search banners default to Contains instead of Starts With
# defaults write com.apple.Safari FindOnPageMatchesWordStartsOnly -bool false

# # Remove useless icons from Safari’s bookmarks bar
# defaults write com.apple.Safari ProxiesInBookmarksBar "()"

# # Enable the Develop menu and the Web Inspector in Safari
# defaults write com.apple.Safari IncludeDevelopMenu -bool true
# defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
# defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled -bool true

# # Add a context menu item for showing the Web Inspector in web views
# defaults write NSGlobalDomain WebKitDeveloperExtras -bool true

# ###############################################################################
# # Spotlight                                                                   #
# ###############################################################################

# # Hide Spotlight tray-icon (and subsequent helper)
# # sudo chmod 600 /System/Library/CoreServices/Search.bundle/Contents/MacOS/Search
# # Disable Spotlight indexing for any volume that gets mounted and has not yet
# # been indexed before.
# # Use `sudo mdutil -i off "/Volumes/foo"` to stop indexing any volume.
# sudo defaults write /.Spotlight-V100/VolumeConfiguration Exclusions -array "/Volumes"

# # Load new settings before rebuilding the index
# killall mds > /dev/null 2>&1
# # Make sure indexing is enabled for the main volume
# sudo mdutil -i on / > /dev/null
# # Rebuild the index from scratch
# sudo mdutil -E / > /dev/null

###############################################################################
# Terminal & iTerm 2                                                          #
###############################################################################

# Only use UTF-8 in Terminal.app
defaults write com.apple.terminal StringEncodings -array 4

# Don’t display the annoying prompt when quitting iTerm
defaults write com.googlecode.iterm2 PromptOnQuit -bool false

###############################################################################
# Time Machine                                                                #
###############################################################################

# Prevent Time Machine from prompting to use new hard drives as backup volume
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

# Disable local Time Machine backups
# hash tmutil &> /dev/null && sudo tmutil disablelocal  # Disabled due to unrecognized verb error

###############################################################################
# Activity Monitor                                                            #
###############################################################################

# Show the main window when launching Activity Monitor
defaults write com.apple.ActivityMonitor OpenMainWindow -bool true

# Visualize CPU usage in the Activity Monitor Dock icon
defaults write com.apple.ActivityMonitor IconType -int 5

# Show all processes in Activity Monitor
defaults write com.apple.ActivityMonitor ShowCategory -int 0

# Sort Activity Monitor results by CPU usage
defaults write com.apple.ActivityMonitor SortColumn -string "CPUUsage"
defaults write com.apple.ActivityMonitor SortDirection -int 0

###############################################################################
# Address Book, Dashboard, iCal, TextEdit, and Disk Utility                   #
###############################################################################

# Use plain text mode for new TextEdit documents
defaults write com.apple.TextEdit RichText -int 0

# Open and save files as UTF-8 in TextEdit
defaults write com.apple.TextEdit PlainTextEncoding -int 4
defaults write com.apple.TextEdit PlainTextEncodingForWrite -int 4

# Enable the debug menu in Disk Utility
defaults write com.apple.DiskUtility DUDebugMenuEnabled -bool true
defaults write com.apple.DiskUtility advanced-image-options -bool true

###############################################################################
# Mac App Store                                                               #
###############################################################################

# Enable the WebKit Developer Tools in the Mac App Store
defaults write com.apple.appstore WebKitDeveloperExtras -bool true

# Enable Debug Menu in the Mac App Store
defaults write com.apple.appstore ShowDebugMenu -bool true

###############################################################################
# Transmission.app                                                            #
###############################################################################

# Trash original torrent files
defaults write org.m0k.transmission DeleteOriginalTorrent -bool true

# Hide the donate message
defaults write org.m0k.transmission WarningDonate -bool false

# Hide the legal disclaimer
defaults write org.m0k.transmission WarningLegal -bool false

###############################################################################
# Security					                                                  #
###############################################################################

# Captive Portal
# https://github.com/drduh/OS-X-Security-and-Privacy-Guide
sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.captive.control Active -bool false

###############################################################################
# Kill affected applications                                                  #
###############################################################################

for app in "Activity Monitor" "Address Book" "Calendar" "Contacts" "cfprefsd" \
	"Dock" "Finder" "Mail" "Messages" \
	"SystemUIServer" "Terminal" \
	"Transmission"; do
	killall "${app}" > /dev/null 2>&1
done
echo "Done. Note that some of these changes require a logout/restart to take effect."

###############################################################################
# Software                                                                    #
###############################################################################

# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install brew packages
./packages.sh

# Symlink all dotfiles recursively
symlink_dotfiles

###############################################################################
# Git					                                                  #
###############################################################################

echo "Configuring Git..."
git config --global core.attributesfile '~/.gitattributes'
git config --global core.excludesfile '~/.gitignore_global'
