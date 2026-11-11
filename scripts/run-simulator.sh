#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 1 ]]; then
    echo "사용법: $0 <시뮬레이터 UUID>"
    xcrun simctl list devices available
    exit 2
fi

cd "$(dirname "$0")/.."
device="$1"
build_dir="$PWD/.build/TripJJIM"
bundle_id="com.tripjjim.TripJJIM"

xcodebuild -project TripJJIM.xcodeproj -scheme TripJJIM -configuration Debug \
    -destination "platform=iOS Simulator,id=$device" -derivedDataPath "$build_dir" \
    CODE_SIGNING_ALLOWED=NO build
xcrun simctl bootstatus "$device" -b
xcrun simctl install "$device" "$build_dir/Build/Products/Debug-iphonesimulator/TripJJIM.app"
xcrun simctl launch --terminate-running-process "$device" "$bundle_id"
