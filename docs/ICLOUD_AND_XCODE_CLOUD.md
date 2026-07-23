# Peak iCloud and Xcode Cloud workflow

## Canonical Apple identifiers

- Bundle identifier: `com.peak.health`
- Apple Developer team: `JJJ3DUS2RQ`
- CloudKit container: `iCloud.com.nexcode.peak.health`

The CloudKit container must match in Signing & Capabilities, `Peak.entitlements`, the provisioning profile, and `PeakConstants.cloudKitContainer`.

## Validate iCloud during development

1. Use the current Xcode version that supports the iOS version on the test phone. In Xcode Settings → Locations, select that same Xcode under Command Line Tools.
2. Open `Peak.xcodeproj`, select the Peak target, and open Signing & Capabilities.
3. Confirm the team is selected and iCloud → CloudKit includes only `iCloud.com.nexcode.peak.health`.
4. On the phone, sign into iCloud and enable iCloud Drive for Peak.
5. Build and run Peak on the phone. SwiftData opens the private CloudKit store and registers the development schema.
6. In You → App Settings, confirm the status reads **iCloud Sync Active** and the mode is `cloudKitPrivate` or `cloudKitAutomatic`.
7. In CloudKit Console, select `iCloud.com.nexcode.peak.health` and the Development environment. Confirm Peak's record types appear and that records arrive after creating data in the app.
8. Test with a second device using the same iCloud account: create a harmless test entry on device A, allow both devices time to sync, and confirm it appears on device B. Repeat in the opposite direction.

Do not delete the app or reset the CloudKit cache as a routine step; those actions are recovery tools. Before TestFlight or App Store distribution, deploy the Development schema to Production in CloudKit Console.

## Prepare Xcode Cloud

Xcode Cloud clones a remote Git repository. Peak therefore needs at least one commit on `main` and a remote repository before the first workflow can run.

1. Review the local files, create the first Git commit, and push `main` to GitHub, Bitbucket, or GitLab.
2. Confirm an App Store Connect app record exists for bundle identifier `com.peak.health` under team `JJJ3DUS2RQ`.
3. In Xcode's Report navigator, select the Cloud tab and choose Get Started.
4. Select the Peak product and Peak scheme, then authorize Xcode Cloud to access the remote repository.
5. Keep the first workflow simple:
   - Start condition: changes to `main` and pull requests targeting `main`.
   - Actions: Build and Test.
   - Xcode version: the same supported version used locally, not an older image.
6. After that workflow passes, add a release workflow on changes to `main` with Analyze and Archive actions and optional TestFlight distribution.

The shared Peak scheme already archives the app in Release mode and builds PeakTests only for testing. RiveRuntime is a public Swift Package dependency, so no secret package credentials are required.

## Quick local checks

Run:

```sh
./scripts/verify_cloud_configuration.sh
```

Then run a normal app build and test build with the same Xcode version selected for Xcode Cloud.
