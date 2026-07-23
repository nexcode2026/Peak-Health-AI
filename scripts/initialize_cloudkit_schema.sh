#!/bin/bash
set -euo pipefail

echo "=== Peak CloudKit Schema Setup ==="
echo ""
echo "1. Open Peak.xcodeproj in Xcode"
echo "2. Select Peak target → Signing & Capabilities"
echo "3. Enable iCloud → CloudKit → container: iCloud.com.nexcode.peak.health"
echo "4. Sign into iCloud on your Mac AND on the test iPhone/simulator"
echo "5. Select your iPhone as the run destination"
echo "6. Build and run the development-signed app; SwiftData registers the development schema"
echo "7. In CloudKit Console, verify the record types in the Development environment"
echo "8. In Peak app: tap 'Reset iCloud Cache' only if the status still shows a store error, then force quit and reopen"
echo "9. Before TestFlight/App Store, deploy the development schema to Production in CloudKit Console"
echo ""
echo "Success: Today tab has no red iCloud banner; You → Settings shows 'iCloud Sync Active'"
echo "Console log: SwiftData CloudKit loaded (simple-private, iCloud.com.nexcode.peak.health)"
