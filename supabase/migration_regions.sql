-- ============================================================
-- Smart Shop – Migration: On-Demand-Regionen (Phase 2.5)
-- Neue Tabelle `regions` (Sync-Cache pro PLZ) + `region`-Spalte
-- auf `offers`. Idempotent – kann gefahrlos erneut laufen.
-- ============================================================

-- Region-Cache: welche PLZ wurde wann zuletzt gesynct
create table if not exists public.regions (
    plz          text primary key,
    last_synced  timestamptz,
    active       boolean not null default true
);
alter table public.regions add column if not exists active boolean not null default true;

alter table public.regions enable row level security;

drop policy if exists "Public read" on public.regions;
create policy "Public read" on public.regions
    for select using (true);

-- App darf neue Regionen anfordern (anon INSERT von {plz}, RegionService.requestRegion).
--
-- Härtung (F5/F13): anon/authenticated dürfen NUR die `plz` liefern, nicht die
-- Queue-Steuer-Spalten `last_synced`/`active`. Ohne diese Einschränkung könnte
-- jeder Halter des öffentlichen anon key den 24h-Cache vordatieren (last_synced
-- setzen → Sync-Queue aushungern) oder Regionen (de)aktivieren (active). Deshalb
-- Spalten-Grant nur auf (plz); die übrigen Spalten füllen ihre Defaults
-- (last_synced → NULL, active → true). Der Service-Sync schreibt über
-- service_role (BYPASSRLS) und ist von Grant und Policy nicht betroffen.
--
-- Hinweis (F13/F5, Dispatch-Throttle): Der AFTER-INSERT-Trigger, der pro neuer
-- PLZ einen GitHub-workflow_dispatch mit dem Vault-PAT anstößt, ist in DIESEM
-- Repo nicht definiert (liegt im Backend-Repo). Der Per-PLZ-Cooldown gegen
-- unbegrenzte CI-Läufe wird deshalb im Backend-Patch am Trigger umgesetzt; hier
-- bleibt es bei der Policy-/Spalten-Härtung.
revoke insert on public.regions from anon, authenticated;
grant  insert (plz) on public.regions to anon, authenticated;

drop policy if exists "Anon request region" on public.regions;
create policy "Anon request region" on public.regions
    for insert with check (
        plz ~ '^[0-9]{5}$'
        and last_synced is null
        and active is true
    );

drop policy if exists "Service write" on public.regions;
create policy "Service write" on public.regions
    for all using (auth.role() = 'service_role');

-- Verfügbare Märkte pro Region (für den Wunschmarkt-Picker der App).
-- Wird vom Sync auf Ketten-Ebene befüllt (eine Zeile pro Kette+PLZ).
create table if not exists public.markets (
    market_id    text primary key,
    chain        text not null,
    branch_name  text not null,
    plz          text not null,
    updated_at   timestamptz default now()
);

alter table public.markets enable row level security;

drop policy if exists "Public read" on public.markets;
create policy "Public read" on public.markets
    for select using (true);

drop policy if exists "Service write" on public.markets;
create policy "Service write" on public.markets
    for all using (auth.role() = 'service_role');

create index if not exists markets_plz_idx on public.markets (plz);

-- offers: Region (PLZ), aus der die Angebote stammen
alter table public.offers add column if not exists region text;

-- Bestandsdaten stammen aus dem bisherigen Dresden-Sync (PLZ 01219)
update public.offers set region = '01219' where region is null;

-- Unique-Constraint um region erweitern: dasselbe (bundesweite) Angebot
-- darf in mehreren Regionen existieren
alter table public.offers drop constraint if exists offers_market_product_valid_from_key;
create unique index if not exists offers_market_product_valid_region_key
    on public.offers (market, product, valid_from, region);

create index if not exists offers_region_idx on public.offers (region);

-- Bisherige Sync-Region als bekannte Region eintragen
insert into public.regions (plz) values ('01219') on conflict do nothing;
