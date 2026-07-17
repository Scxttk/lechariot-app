# Smartshop

Monorepo for the Smartshop app — grocery offers for your region, backed by Supabase (data sourced via the Marktguru API).

## Structure

- `ios/` — SwiftUI iOS app (iOS 17+, no third-party dependencies)
- `docs/` — data contracts and architecture notes

## iOS setup

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
2. Copy `ios/Smartshop/Resources/APIKeys.example.plist` to `ios/Smartshop/Resources/APIKeys.plist` and fill in the Supabase publishable key.
3. Regenerate the project if `project.yml` changed: `cd ios && xcodegen`
4. Build:

```sh
xcodebuild -project ios/Smartshop.xcodeproj -scheme Smartshop -destination 'generic/platform=iOS Simulator' build
```

## Data contracts

See [docs/CONTRACTS.md](docs/CONTRACTS.md).
