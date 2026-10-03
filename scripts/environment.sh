#!/bin/bash
# Source from other scripts. Never changes global xcode-select.
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Keep signed bundles away from File Provider/Finder metadata in synced Documents.
project_key="$(printf '%s' "$PROJECT_ROOT" | shasum -a 256 | cut -c 1-12)"
export PHOTOAXIS_BUILD_ROOT="${PHOTOAXIS_BUILD_ROOT:-$HOME/Library/Developer/PhotoAxisBuilds/$project_key}"
mkdir -p "$PHOTOAXIS_BUILD_ROOT"
if [[ -z "${DEVELOPER_DIR:-}" ]]; then
  selected="$(xcode-select -p)"
  if [[ "$selected" == */CommandLineTools && -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
  fi
fi
cd "$PROJECT_ROOT"
