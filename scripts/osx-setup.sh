#!/bin/env bash


# echo "Setup groups"
# sudo dscl . create /Groups/brew
# sudo dscl . create /Groups/brew RealName "brew"
# sudo dscl . create /Groups/brew passwd "*"
# sudo dscl . create /Groups/brew gid "2511"
# sudo chgrp -R brew $(brew --prefix)/*
# sudo chmod -R g+w $(brew --prefix)/*
# sudo dscl . create /Groups/brew GroupMembership `whoami`

echo "Configure osx dock settings"
sudo cp osx/com.apple.dock.plist ${HOME}/Library/Preferences/com.apple.dock.plist
killall Dock

echo "Configuring finder to quit"
defaults write com.apple.finder QuitMenuItem -bool YES
killall Finder

echo "Expand save panel by default"
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true

echo "Expand print panel by default"
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true

echo "Save to disk by default"
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

echo "Automatically quit printer app when print complete"
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true

# echo "Reveal IP address, hostname on clicking clock"
# sudo defaults write /Library/Preferences/com.apple.loginwindow AdminHostInfo HostName
# echo "Restart on freeze"
# systemsetup -setrestartfreeze on

# echo "Disable local Time Machine snapshots"
# sudo tmutil disablelocal

# echo "Disable hibernation (speeds up entering sleep mode)"
# sudo pmset -a hibernatemode 0

# echo "Remove the sleep image file to save disk space"
# sudo rm /Private/var/vm/sleepimage

# echo "Create a zero-byte file instead..."
# sudo touch /Private/var/vm/sleepimage

# echo "...and make sure it can’t be rewritten"
# sudo chflags uchg /Private/var/vm/sleepimage

# echo "Disable the sudden motion sensor as it’s not useful for SSDs"
# sudo pmset -a sms 0

echo "Disable autocorrect"
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

echo "save screenshots in png format"
defaults write com.apple.screencapture type -string "png"

echo "Show all filename extensions"
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

echo "show ~/Library"
chflags nohidden ~/Library

# echo "disable spotlight for volumes"
# sudo defaults write /.Spotlight-V100/VolumeConfiguration Exclusions -array "/Volumes"
# killall mds > /dev/null 2>&1

printf "Please log out and log back in to make all settings take effect.\n"
