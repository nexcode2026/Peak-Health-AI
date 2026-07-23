# Peak

**Peak** is a premium native iOS health, recovery, sleep, fitness, and lifestyle tracking app. Built with SwiftUI, SwiftData, CloudKit, HealthKit, StoreKit 2, and a hybrid AI coach (on-device + optional OpenAI Responses API).

> Peak is a wellness tool, not a medical device. It does not diagnose, treat, or prevent any condition.

## Requirements

- Xcode 16+ (tested on Xcode 26.1)
- iOS 18.0+ deployment target
- Apple Developer Program membership for device testing & App Store
- macOS with iOS Simulator or physical iPhone

## Quick Start

```bash
cd Developer/Peak
open Peak.xcodeproj
```

1. Select your **Development Team** in Signing & Capabilities (Peak target).
2. Choose an iOS Simulator (e.g. iPhone 16, iOS 18.5+).
3. Press **⌘R** to build and run.
4. Complete onboarding: goals → permissions → Sign in with Apple.
5. Enable **"Load sample data"** during onboarding for instant demo content.

### StoreKit Testing

The scheme includes `Peak.storekit` for local subscription testing. In Xcode: **Product → Scheme → Edit Scheme → Run → Options → StoreKit Configuration → Peak.storekit**.

## Architecture

```
Peak/
├── PeakApp.swift              # @main, TabView, SwiftData + CloudKit container
├── Core/                      # Theme, Constants, Extensions, Haptics, Errors
├── Models/                    # SwiftData @Model types + export DTOs
├── Services/                  # Protocol-based services (testable)
│   ├── HealthKitService       # Read/write HealthKit, background delivery
│   ├── RecoveryScoringService # Weighted 0–100 recovery algorithm
│   ├── AuthService            # Sign in with Apple
│   ├── SubscriptionService    # StoreKit 2 subscriptions
│   ├── AIService              # OpenAI Responses API + on-device fallback
│   ├── NotificationService    # Local + rich notification categories
│   ├── ExportService          # CSV + PDF reports
│   ├── BiometricAuthService   # Face ID / Touch ID
│   └── AppContainer           # Dependency injection
├── Features/
│   ├── Dashboard/             # Recovery hero, rings, insights
│   ├── Logging/               # Habits, hydration, mood
│   ├── Insights/              # Swift Charts analytics
│   ├── Coach/                 # AI chat interface
│   ├── Profile/               # Settings, paywall, export
│   └── Onboarding/            # Multi-step first-run flow
├── Views/DesignSystem/        # Reusable UI components
├── ViewModels/                # @Observable per-feature VMs
├── Assets.xcassets            # Brand colors + App Icon slot
├── Peak.entitlements          # HealthKit, CloudKit, Sign in with Apple
├── PrivacyInfo.xcprivacy      # App Store privacy manifest
└── Peak.storekit              # Local IAP testing config
```

### Recovery Scoring (Documented Weights)

| Factor | Weight | Inputs |
|--------|--------|--------|
| Sleep | 30% | Duration (7–9h optimal), quality from stages |
| HRV / Resting HR | 25% | SDNN, 7-day trend |
| Activity Balance | 15% | Steps, active energy, strain balance |
| Hydration | 10% | Daily ml vs goal |
| Mood | 10% | 1–5 rating |
| Habits | 10% | Completion rate + streak bonus |

### Subscription Tiers

| Tier | Habits | AI Messages/mo | History |
|------|--------|----------------|---------|
| Free | 3 | 10 | 14 days |
| Premium | Unlimited | 500 | 5 years |
| Pro | Unlimited | 2000 | 5 years |

**Product IDs:** `com.peak.premium.monthly`, `com.peak.premium.yearly`, `com.peak.pro.monthly`

## Apple Developer Portal Checklist

Enable these capabilities for App ID `com.peak.health`:

- [ ] **Sign in with Apple**
- [ ] **iCloud** → CloudKit → container `iCloud.com.nexcode.peak.health`
- [ ] **HealthKit** (including background delivery)
- [ ] **Push Notifications** (for remote reminders; local works without)
- [ ] **In-App Purchase** (auto-renewable subscriptions)

### App Store Connect

1. Create app record: **Peak**
2. Subtitle: *Recovery & Performance Coach*
3. Create subscription group **Peak Premium** with monthly/yearly/pro products matching `Peak.storekit`
4. Upload screenshots (see Marketing section below)
5. Add privacy policy URL (placeholder: `https://peak-health.app/privacy`)
6. Complete App Privacy questionnaire (Health & Fitness data, User ID — not used for tracking)

### CloudKit Dashboard

1. Open [CloudKit Console](https://icloud.developer.apple.com/)
2. Select container `iCloud.com.nexcode.peak.health`
3. Run a development-signed build on a device signed into iCloud; SwiftData registers the development schema from the `@Model` classes
4. Verify records in the Development environment
5. Deploy the schema to Production before TestFlight or App Store distribution

### OpenAI Coach (Optional)

Users can opt in via **Profile → Peak Coach AI**:

1. Obtain an API key from the [OpenAI platform](https://platform.openai.com/api-keys)
2. Enter it in app Settings (stored in Keychain, never in source code)
3. Explicitly enable OpenAI Coach; the app discloses that a compact wellness summary is sent with each request
4. Peak falls back to its on-device rule-based coach when OpenAI is disabled or unavailable

## App Icon Guidance

Design a **1024×1024** minimalist icon:

- Stylized mountain peak or upward arrow motif
- Gradient: deep teal (#1C5F7D) → vibrant coral (#FF6B4A)
- Clean geometry, no text, works at small sizes
- Add PNG to `Assets.xcassets/AppIcon.appiconset/`

## Marketing & Screenshots (6.7" iPhone)

| # | Screen | Caption |
|---|--------|---------|
| 1 | Dashboard with recovery gauge at 82 | "Your daily recovery score — know when to push and when to rest" |
| 2 | Track tab — habits checked off | "Micro-habits that compound into peak performance" |
| 3 | Insights recovery trend chart | "Beautiful analytics reveal what drives your best days" |
| 4 | Coach chat with plan | "Peak Coach — private AI guidance grounded in your data" |
| 5 | Hydration + mood logging | "Log hydration, mood, and reflections in seconds" |
| 6 | Paywall / Premium features | "Go Premium for unlimited habits, full history, and advanced AI" |

**Keywords:** recovery, sleep, HRV, habits, hydration, wellness, fitness, health tracker, AI coach, performance

**Description (excerpt):** Peak helps you achieve sustainable peak performance through intelligent recovery scoring, HealthKit integration, micro-habit tracking, and your private AI coach. Not a medical device.

## TestFlight / Review Notes

- Position as **wellness / fitness**, not medical diagnostics
- Provide sandbox Apple ID for reviewer
- Note: Sign in with Apple required; HealthKit optional but enhances recovery score
- Sample data available via onboarding toggle
- Medical disclaimer visible on Coach tab and About section

## Running Tests

```bash
xcodebuild -project Peak.xcodeproj -scheme Peak \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' test
```

Tests cover recovery scoring engine and subscription tier limits.

## Known Limitations

- Alternate app icons require the final App Store asset variants to be added to the target before release
- CloudKit requires Apple Developer account + iCloud signed in on device
- HealthKit data sparse in Simulator — use physical device or sample data
- OpenAI Coach requires a user-provided API key (no bundled credentials)
- Photo attachments use local paths; full CKAsset upload is scaffolded via `photoAssetIdentifier`
- Remote push requires APNs certificate configuration

## Iteration Roadmap

1. **v1.1** — Widgets (recovery score, hydration), Apple Watch companion
2. **v1.2** — Foundation Models on-device when Apple Intelligence available
3. **v1.3** — Social challenges, shared habit accountability (CloudKit sharing)
4. **v1.4** — Advanced correlations ML, custom recovery weight tuning
5. **v2.0** — iPad-optimized layouts, multi-user family profiles

## Regenerating Xcode Project

If you add new Swift files:

```bash
python3 scripts/generate_xcode_project.py
```

Then re-add your Development Team in Xcode.

## License

Proprietary — All rights reserved. Configure license before open-sourcing.
