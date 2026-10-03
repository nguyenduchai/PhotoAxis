#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/environment.sh"
configuration="${1:-Debug}"
if [[ "$configuration" != Debug && "$configuration" != Release ]]; then
  echo "Usage: scripts/build.sh [Debug|Release]" >&2
  exit 2
fi
xcodebuild -checkFirstLaunchStatus
xcodebuild -project PhotoAxis.xcodeproj -scheme PhotoAxis -configuration "$configuration" \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath "$PHOTOAXIS_BUILD_ROOT/DerivedData" \
  CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= build
echo "App: $PHOTOAXIS_BUILD_ROOT/DerivedData/Build/Products/$configuration/PhotoAxis.app"
