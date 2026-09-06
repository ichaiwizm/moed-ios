# Moed — iOS

Native SwiftUI app for the Jewish calendar (*louah*): today's Hebrew date, zmanim for your city,
Shabbat candle lighting and havdala, weekly parasha and haftara, the Omer count, hiloulot, and
personal Hebrew birthdays and yahrzeits — computed entirely on the device.

**No backend, no account, no network.** Every date and every time is derived on-device from a pure
Swift astronomical engine and static bundled datasets, so the app works fully offline and costs
nothing to run per user.

## Architecture

- **Pure Swift halakhic engine** (`Sources/Moed/Engine/`) — the NOAA solar algorithm ported from
  KosherJava to Swift, plus Hebrew date conversion, candle lighting, haftara tables and gematria.
  No SPM runtime dependency: nothing is pulled at build time to compute a zman.
- **Blocking validation test** (`Sources/MoedTests/ZmanimValidationTests.swift`) — replays a frozen
  reference fixture (`kosher_zmanim_reference.json`, exported offline from `kosher-zmanim` and
  `@hebcal/core`) over a matrix of 10 cities x 2 years x 4 date kinds x 16 zmanim. Hebrew dates must
  match exactly; a zman is a failure past 2 minutes of deviation. The suite runs offline in CI.
- **SwiftUI feature modules** — Today, Calendar, Personal (family book of birthdays and yahrzeits),
  Tsadikim, Settings, plus zmanim-by-city and a Hebrew/Gregorian converter.
- **Design system** (`Sources/Moed/DesignSystem/`) — colour sets, typography, elevation, glass
  surfaces and an explicit RTL mirroring layer, since Hebrew is a first-class locale.
- **Trilingual at parity** — Hebrew (RTL), French and English, via `.lproj` string tables.
- **Local notifications only** — candle lighting, Omer, yahrzeits and holidays are deterministic, so
  they are scheduled ahead on the device instead of through a push server.
- **Project generated, not committed** — `project.yml` (XcodeGen) is the source of truth; CI
  regenerates the `.xcodeproj`. Three GitHub Actions workflows cover release, App Store metadata,
  and App Store screenshots driven by Maestro on a simulator.

## Stack

Swift 5.9, SwiftUI, iOS 17+, strict concurrency. XcodeGen, Fastlane (match, TestFlight, deliver),
Maestro, GitHub Actions (macOS runners). WidgetKit sources are present but excluded from the v1
build.

## Build

```bash
brew install xcodegen
xcodegen generate
open Moed.xcodeproj      # or: xcodebuild -scheme Moed -destination 'generic/platform=iOS Simulator'
```

Tests, including the halakhic validation matrix:

```bash
xcodebuild test -scheme Moed -destination 'platform=iOS Simulator,name=iPhone 15'
```

Release and store lanes (`bundle exec fastlane beta` / `release`) expect signing and App Store
Connect credentials injected from CI secrets; they are not usable from a clean clone.

## Status

Version 1.0 was submitted to the App Store in July 2026 (bundle id `com.wizycode.moed`), with the
build attached and valid, awaiting review. Not yet publicly released.

## Licence

No licence granted. Published for reading.
