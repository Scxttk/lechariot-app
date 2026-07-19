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

## Edge Functions

### `sync-region`

On-demand offer sync for a region via Marktguru (source of truth:
`supabase/functions/sync-region/`, deploy with `supabase functions deploy sync-region`).

```
POST {SupabaseURL}/functions/v1/sync-region   body: {"zip": "04626"}
```

Headers as above (publishable key is sufficient). Optional `"force": true`
bypasses the 24h cache (used by the daily refresh workflow, service key).

Responses:

```
{"cached": true,  "zip": "04626", "count": 2513}                      // cache fresh (<24h)
{"cached": false, "zip": "04626", "markets": 4, "count": 1543, "failed": []}
```

Behavior: claims `regions.last_synced` first (parallel calls return `cached`),
resolves the region's retailers from the Marktguru search API, upserts offers
with `region = zip` on conflict `(market, product, valid_from, region)`.
`markets` is owned by the branch pipeline and never written here.

Note: offer categories written by this function still use the legacy 9-category
set, not the 15 categories above; unknown categories must fall back to Sonstiges.
