#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"

expected_bundle="com.peak.health"
expected_container="iCloud.com.nexcode.peak.health"

entitled_container="$(/usr/libexec/PlistBuddy -c 'Print :com.apple.developer.icloud-container-identifiers:0' Peak/Peak.entitlements)"
code_container="$(sed -n 's/.*cloudKitContainer = "\([^"]*\)".*/\1/p' Peak/Core/Constants.swift)"

test "$entitled_container" = "$expected_container" || {
    echo "FAIL: entitlement uses $entitled_container; expected $expected_container"
    exit 1
}

test "$code_container" = "$expected_container" || {
    echo "FAIL: app code uses $code_container; expected $expected_container"
    exit 1
}

project_bundle="$(xcodebuild -project Peak.xcodeproj -scheme Peak -showBuildSettings 2>/dev/null | sed -n 's/^[[:space:]]*PRODUCT_BUNDLE_IDENTIFIER = //p' | head -1)"
test "$project_bundle" = "$expected_bundle" || {
    echo "FAIL: project uses $project_bundle; expected $expected_bundle"
    exit 1
}

xcodebuild -project Peak.xcodeproj -describeAllArchivableProducts -json 2>/dev/null | grep -q '"bundleIdentifier" : "com.peak.health"' || {
    echo "FAIL: Xcode cannot discover Peak as an archivable product"
    exit 1
}

echo "PASS: bundle ID, CloudKit container, entitlement, and archive scheme agree"
xcodebuild -version

if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
    echo "XCODE CLOUD BLOCKED: create the first Git commit"
elif ! git remote get-url origin >/dev/null 2>&1; then
    echo "XCODE CLOUD BLOCKED: add and push an origin remote"
else
    echo "XCODE CLOUD READY: Git history and origin remote are present"
fi
