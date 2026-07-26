# Le Chariot

Monorepo for the Le Chariot app — grocery offers for your region, backed by Supabase.

Offers are scraped by the Rust backend in [lechariot-backend](https://github.com/Scxttk/lechariot-backend) and pushed to Supabase; this repo only reads them. Seven of the eight chains come from the retailers' own endpoints (Kaufland, REWE, Netto, Penny, EDEKA, ALDI Nord, ALDI SÜD). Lidl is the exception: its own API requires OAuth, so those offers come via the public Marktguru web API — roughly 30 % of all rows.

## Structure

- `ios/` — SwiftUI iOS app (iOS 17+, no third-party dependencies)
- `docs/` — data contracts and architecture notes
- `tools/` — one-off generators; `icon.swift` draws the three app-icon
  variants from the proportions at the top of the file
  (`swiftc -O tools/icon.swift -o /tmp/icon && /tmp/icon ios/LeChariot/Assets.xcassets/AppIcon.appiconset/`)

## iOS setup

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
2. Copy `ios/LeChariot/Resources/APIKeys.example.plist` to `ios/LeChariot/Resources/APIKeys.plist` and fill in the Supabase publishable key.
3. Regenerate the project if `project.yml` changed: `cd ios && xcodegen`
4. Build:

```sh
xcodebuild -project ios/LeChariot.xcodeproj -scheme LeChariot -destination 'generic/platform=iOS Simulator' build
```

## Data contracts

See [docs/CONTRACTS.md](docs/CONTRACTS.md).
