# Supabase Data Contracts

Base URL: `https://cddubgdnasmzvcfhmrzj.supabase.co`

All requests go to the PostgREST endpoint: `{SupabaseURL}/rest/v1/{table}` with headers:

```
apikey: {SupabaseKey}
Authorization: Bearer {SupabaseKey}
```

Writes additionally send `Content-Type: application/json` and `Prefer: return=minimal`.
`SupabaseKey` is an `sb_publishable_...` key, stored locally in the gitignored `APIKeys.plist`.

## Tables

### `offers`

| Column | Type | Notes |
| --- | --- | --- |
| `market` | text | Chain name, e.g. `"Lidl"` |
| `product` | text | Product name |
| `price` | double? | Offer price in EUR |
| `regular_price` | double? | Regular (non-offer) price |
| `unit` | text? | e.g. `"je 12 x 1 l"` |
| `category` | text | One of the 15 fixed German categories (below) |
| `emoji` | text? | Display emoji |
| `valid_from` | date | `"yyyy-MM-dd"` string |
| `valid_until` | date | `"yyyy-MM-dd"` string |
| `base_price` | double? | Price per base unit |
| `base_unit` | text? | e.g. `"1 kg"` |
| `region` | text | PLZ, e.g. `"01219"` |
| `image_url` | text? | Public Supabase-Storage URL of the product image. Content-addressed and stable — safe to cache aggressively. `null` = app shows the emoji instead. |

Typical query:

```
GET /rest/v1/offers?select=*&order=valid_from.desc&region=in.(01219)&market=in.(Lidl,Aldi)&limit=1000&offset=0
```

Paginated 1000 rows per page via `limit`/`offset`.

`region=in.(...)` carries all of the user's ready regions in one request
(e.g. `region=in.(01219,01067)` for PLZ-border users), not just the selected one.

The `market=in.(...)` filter is optional: the app sends it with the user's favorite
chains ("Wunschmärkte") and omits it to fetch all chains. Chain names are
percent-encoded (they may contain spaces, e.g. `Netto Marken-Discount`).

### `markets`

| Column | Type | Notes |
| --- | --- | --- |
| `chain` | text | Chain name |
| `branch_name` | text | Branch/store name |
| `market_id` | text | Stable id |
| `plz` | text | PLZ |

```
GET /rest/v1/markets?select=chain,branch_name,market_id,plz&plz=in.(01219)&order=chain.asc,branch_name.asc
```

### `branches`

The store directory (backend migration v12). Different question from
`markets`: that table holds the *one* store the backend scraped per chain and
PLZ, which is why the second REWE in a postcode was unreachable. `branches`
holds every store the chains' own finders know about, with coordinates.
Public read, no writes — it is backend data, not a queue.

| Column | Type | Notes |
| --- | --- | --- |
| `market_id` | text | Primary key, the chain's own branch id |
| `chain` | text | Chain name, identical to `offers.market` |
| `name` | text | Branch name |
| `street`, `plz`, `city` | text? | Optional — the eight finders return different detail |
| `lat`, `lon` | float8? | Optional; rows without them cannot be sorted by distance |

Nearby search is a **bounding box**, not a radius: there is no PostGIS in the
free tier, and two btree columns (`branches_lat_lon_idx`) answer a range
instantly. The box is larger than the circle, so the client drops what lies
outside the radius itself (`Geo`, `LiveBranchRepository`).

```
GET /rest/v1/branches?select=market_id,chain,name,street,plz,city,lat,lon&lat=gte.50.96&lat=lte.51.14&lon=gte.13.59&lon=lte.13.87&limit=200
GET /rest/v1/branches?select=…&market_id=eq.1766063&limit=1
```

### `branch_requests`

The app's way of asking for one store's offers (backend migration v14). Same
shape as `regions`, one level more precise: inserting a row fires the trigger
`on_branch_request_insert`, which dispatches the backend's `nightly.yml` with
`inputs.market_id`; the app polls `last_synced`.

| Column | Type | Notes |
| --- | --- | --- |
| `market_id` | text | Primary key; **must exist in `branches`** |
| `last_synced` | text? | null = still waiting |
| `active` | bool? | Whether the store is kept in sync |

The insert is restricted server-side to the `market_id` column, and the id has
to be in the directory. Verified with the app's own publishable key on
2026-07-25: an invented id is rejected with `42501`, naming a control column
fails with "permission denied for column", reading is allowed. That check is
what the PLZ path never had — it is how the non-existent postcode 94108 became
an active region.

Measured the same day, end to end: insert → dispatched workflow **1 second**,
insert → 162 finished offers **43 seconds**.

```
GET  /rest/v1/branch_requests?select=market_id,last_synced,active&market_id=eq.1763556
POST /rest/v1/branch_requests   body: {"market_id": "1763556"}   (409 = already requested, treat as success)
```

### `regions`

| Column | Type | Notes |
| --- | --- | --- |
| `plz` | text | Primary key |
| `last_synced` | text? | Timestamp string |
| `active` | bool? | Whether the region is being synced |

```
GET  /rest/v1/regions?select=plz,last_synced,active&plz=eq.01219
POST /rest/v1/regions   body: {"plz": "01219"}   (409 conflict = already registered, treat as success)
```

## Categories (fixed, 15)

Kept in sync with the backend enrichment step:

Obst & Gemüse, Molkerei & Eier, Fleisch & Wurst, Fisch, Backwaren, Tiefkühl,
Süßes & Snacks, Getränke, Alkohol, Vorräte & Kochen, Drogerie, Haushalt,
Tierbedarf, Kinder, Sonstiges

## Date handling

`valid_from` / `valid_until` are plain `yyyy-MM-dd` strings (no time, no timezone).
The app decodes them with a fixed `DateFormatter` (`en_US_POSIX`, format `yyyy-MM-dd`).

## On-demand region sync

There is no Edge Function. Inserting a row into `regions` fires the database
trigger `on_region_insert`, which dispatches the `nightly.yml` workflow in
[smartshop-backend](https://github.com/Scxttk/smartshop-backend) via `pg_net`.
The app writes the row (`LiveRegionRepository.registerRegion`, publishable key,
insert is column-restricted to `plz`) and then polls `regions.last_synced` for
the result. Measured 2026-07-25: insert to finished offers took two minutes.

The Deno function `sync-region` that used to do this was removed on 2026-07-25
along with the `region_refresh.yml` workflow. It fetched every chain from
Marktguru and was fully superseded by the Rust scrapers, which read seven of
the eight chains from the retailers themselves.
