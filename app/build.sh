#!/bin/sh
# Builds Vicinitas.app (menu bar only, no Dock icon) next to this script, via the Xcode project.
# Not SwiftPM: a package build stamps the binary with SDK = deployment target,
# which makes macOS 26+ draw the old look (square menu bar panel).
set -e
cd "$(dirname "$0")"
xcodebuild -project Vicinitas.xcodeproj -scheme Vicinitas -configuration Release \
  -destination 'platform=macOS' -derivedDataPath .build/xcode -quiet build
rm -rf Vicinitas.app
cp -R .build/xcode/Build/Products/Release/Vicinitas.app .
echo "Built $(pwd)/Vicinitas.app"
