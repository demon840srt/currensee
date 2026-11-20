#!/usr/bin/env bash
# Check required tools, then generate the Xcode project from project.yml.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

log "Checking Xcode"
command -v xcodebuild >/dev/null || die "xcodebuild not found. Install Xcode from the App Store."
if ! xcode_line="$(xcodebuild -version 2>/dev/null | head -1)"; then
    die "Xcode is not the active developer directory. Run:
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
fi
xcode_major="$(awk '{print $2}' <<<"$xcode_line" | cut -d. -f1)"
[[ "$xcode_major" =~ ^[0-9]+$ ]] || die "Could not parse Xcode version from: $xcode_line"
(( xcode_major >= MIN_XCODE_MAJOR )) || die "Xcode $MIN_XCODE_MAJOR or newer is required (found: $xcode_line)."
echo "    $xcode_line"

log "Checking xcodegen"
command -v xcodegen >/dev/null || die "xcodegen not found. Install it with: brew install xcodegen"
echo "    xcodegen $(xcodegen --version | awk '{print $2}')"

log "Generating Xcode project"
(cd "$APP_DIR" && xcodegen generate --quiet)
echo "    $PROJECT"
