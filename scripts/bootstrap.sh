#!/usr/bin/env bash
# Sets up the Xcode project on your Mac:
#   1. installs XcodeGen (with Homebrew) if it's missing
#   2. creates Config/Local.xcconfig with a bundle ID unique to you
#   3. generates StopDoomscroll.xcodeproj and opens it
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
  if ! command -v brew >/dev/null 2>&1; then
    echo "XcodeGen is needed, and the easiest way to get it is Homebrew."
    echo "Install Homebrew from https://brew.sh, then run this script again."
    exit 1
  fi
  echo "Installing XcodeGen..."
  brew install xcodegen
fi

if [ ! -f Config/Local.xcconfig ]; then
  echo "Free Apple IDs need a bundle ID that nobody else uses."
  read -r -p "Type a short name for yourself (letters and numbers only, e.g. nickson): " who
  who="$(printf '%s' "$who" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9')"
  if [ -z "$who" ]; then
    who="user$RANDOM"
  fi
  cat > Config/Local.xcconfig <<EOF
// Created by scripts/bootstrap.sh. Git-ignored.
PRODUCT_BUNDLE_IDENTIFIER = com.${who}.stopdoomscroll
DEVELOPMENT_TEAM =
EOF
  echo "Bundle ID: com.${who}.stopdoomscroll (change it in Config/Local.xcconfig)"
fi

xcodegen generate
open StopDoomscroll.xcodeproj

cat <<'EOF'

Next, in Xcode:
  1. Select the StopDoomscroll target → Signing & Capabilities → Team → "<your name> (Personal Team)".
     (No team yet? Xcode → Settings → Accounts → + → Apple ID.)
  2. Plug in your iPhone, pick it as the run destination at the top, press ⌘R.
Then follow docs/SETUP.md for the iPhone side.
EOF
