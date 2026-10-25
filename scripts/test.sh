#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
destination="${TEST_DESTINATION:-platform=iOS Simulator,name=iPhone Duo}"
results="${TEST_RESULTS_DIR:-$PWD/build/test-results/$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$results"
xcrun swift test --package-path AffirmationShared 2>&1 | tee "$results/shared.log"
xcodebuild test -project AffirmationApp.xcodeproj -scheme AffirmationApp \
  -destination "$destination" -parallel-testing-enabled NO \
  -enableCodeCoverage YES -resultBundlePath "$results/app.xcresult" \
  CODE_SIGNING_ALLOWED=NO "$@" 2>&1 | tee "$results/app.log"
xcrun xccov view --report --json "$results/app.xcresult" > "$results/coverage.json"
