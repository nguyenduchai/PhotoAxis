#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/environment.sh"
python3 scripts/generate-project.py --check
python3 scripts/check-localization.py
plutil -lint Config/Info.plist PhotoAxis.xcodeproj/project.pbxproj
xcodebuild -checkFirstLaunchStatus
mkdir -p "$PHOTOAXIS_BUILD_ROOT/test-results"
result="$PHOTOAXIS_BUILD_ROOT/test-results/PhotoAxis-$(date +%Y%m%d-%H%M%S)-$$.xcresult"
xcodebuild -project PhotoAxis.xcodeproj -scheme PhotoAxis -configuration Debug \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath "$PHOTOAXIS_BUILD_ROOT/DerivedData" \
  -resultBundlePath "$result" CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= test
echo "Test result: $result"
