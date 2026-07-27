<p align="center">
  <img src="ios/LeChariot/Assets.xcassets/AppIcon.appiconset/icon-light-1024.png" width="128" alt="Le Chariot icon">
</p>

<h1 align="center">Le Chariot</h1>

<p align="center">Write a shopping list. Find out which of your shops covers it cheapest this week.</p>

<p align="center">
  <img src="https://img.shields.io/badge/iOS-17%2B-black?style=flat-square" alt="iOS 17+">
  <img src="https://img.shields.io/badge/SwiftUI-no%20dependencies-black?style=flat-square" alt="SwiftUI, no dependencies">
  <a href="LICENSE"><img src="https://img.shields.io/github/license/Scxttk/lechariot-app?style=flat-square" alt="MIT license"></a>
</p>

<p align="center">
  <img src="assets/liste.png" width="260" alt="Shopping list with the winning shop at the top">
  <img src="assets/angebote.png" width="260" alt="This week's offers, sorted by discount">
  <img src="assets/filialen.png" width="260" alt="The seven chosen branches in Settings">
</p>

Every German supermarket publishes a weekly leaflet, and comparing them by hand is
miserable — eight apps, eight layouts, and by the time you've checked the fourth one
you've forgotten what Kaufland wanted for butter. So: type what you need, pick the
branches you'd actually drive to, and Le Chariot tells you which single shop covers
the most of your list for the least money.

The screenshot above is a real run in Dresden. Six items, and ALDI Nord covered all
six for 7,80 € — including a Haferdrink at −30 % that I wasn't looking for. Penny won
an earlier round with Sachsenmilch at 0,49 €.

The UI is German and the offers are German. Nothing about the app is portable to other
countries, and I'm not pretending otherwise.

## The interesting part is the matching

You type "Milch". The offer is called "SACHSEN MILCH Buttermilch 500 g". Getting from
one to the other is where all the actual work lives, and it runs in two stages
([`OfferMatcher.swift`](ios/LeChariot/Models/OfferMatcher.swift), 105 lines):

1. **Direct** — every query token must hit a token in the product title. Typo-tolerant
   via Levenshtein distance ≤ 1, but only when both tokens are ≥ 5 characters *and*
   differ in length. The guards matter: without them "Käse" matches "Kekse" and
   "Butter" matches "Bitter". Ask me how I know.
2. **Category** — the query is looked up against `match_key` tags the backend attaches
   during import. The backend dictionary already blocks false composites, so
   Tomatenmark carries no `tomaten` tag and won't show up when you ask for tomatoes.

There's a feedback path in the app for when a match is wrong
([`MatchFeedbackStore`](ios/LeChariot/Stores/MatchFeedbackStore.swift)); I go through the
rejections periodically and fold them back into the dictionary. It is still wrong
sometimes.

## Where the data comes from

Offers are scraped by the Rust backend in
[lechariot-backend](https://github.com/Scxttk/lechariot-backend) and pushed to Supabase;
this repo only reads. All eight chains come from the retailers themselves — seven via
their own endpoints (Kaufland, REWE, Netto, Penny, EDEKA, ALDI Nord, ALDI SÜD), Lidl via
its weekly leaflet PDF (`LIDL_SOURCE=prospekt`; the third-party Marktguru API remains
only as the code's fallback when that variable is unset).

Branch lists are real: enter a postcode and you get actual nearby stores with distances,
which is why the picker in the third screenshot knows about 22 further ALDI Nord
branches around 01219.

## Structure

- `ios/` — SwiftUI iOS app (iOS 17+, no third-party dependencies)
- `docs/` — data contracts and architecture notes
- `tools/` — one-off generators; `icon.swift` draws the three app-icon
  variants from the proportions at the top of the file
  (`swiftc -O tools/icon.swift -o /tmp/icon && /tmp/icon ios/LeChariot/Assets.xcassets/AppIcon.appiconset/`)

## iOS setup

You'll need XcodeGen — the `.xcodeproj` is generated, not committed as the source of truth.

1. `brew install xcodegen` ([XcodeGen](https://github.com/yonaskolb/XcodeGen))
2. Copy `ios/LeChariot/Resources/APIKeys.example.plist` to `ios/LeChariot/Resources/APIKeys.plist` and fill in the Supabase publishable key.
3. Regenerate the project if `project.yml` changed: `cd ios && xcodegen`
4. Build:

```sh
xcodebuild -project ios/LeChariot.xcodeproj -scheme LeChariot -destination 'generic/platform=iOS Simulator' build
```

## Data contracts

See [docs/CONTRACTS.md](docs/CONTRACTS.md).
