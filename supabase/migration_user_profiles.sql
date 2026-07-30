-- ============================================================
-- Le Chariot – Migration: Nutzer-Profile aus dem Onboarding
-- Neue Tabelle `user_profiles`. Idempotent – kann gefahrlos
-- erneut laufen. Berührt den eingefrorenen Rust-Import nicht.
-- ============================================================
--
-- Zwei bewusste Design-Entscheidungen:
--
-- 1) APPEND-ONLY. Jedes Speichern schreibt eine neue Zeile; die jüngste Zeile
--    pro install_id gilt. Ein PostgREST-Upsert bräuchte eine anon-UPDATE-Policy,
--    und mit der könnte jeder, der den öffentlichen anon key hat, fremde Zeilen
--    überschreiben. Insert-only vermeidet das komplett.
--
-- 2) INSERT-Policy, aber KEINE SELECT-Policy für anon. Die App schreibt und
--    liest nie zurück — mit dem anon key sind fremde Profile damit unerreichbar.
--    Ausgewertet wird über service_role.
--
-- Nicht enthalten und bewusst nie übertragen: Vorname, Einkaufsliste und die
-- gewählten Filialen. Die bleiben auf dem Gerät (siehe Models/UserProfile.swift),
-- damit die hier liegenden Daten pseudonym bleiben — install_id ist eine
-- Zufalls-UUID der Installation, aus keiner Geräte-ID abgeleitet.

create table if not exists public.user_profiles (
    id             bigint generated always as identity primary key,
    install_id     uuid        not null,
    created_at     timestamptz not null default now(),
    household_size smallint,
    trips_per_week smallint,
    weekly_budget  smallint,
    diet_tags      text[]      not null default '{}',
    plz            text
);

alter table public.user_profiles enable row level security;

-- App darf Profile anlegen (anon INSERT, ProfileStore.sync)
drop policy if exists "Anon insert profile" on public.user_profiles;
create policy "Anon insert profile" on public.user_profiles
    for insert with check (
        install_id is not null
        and (plz is null or plz ~ '^[0-9]{5}$')
        and (household_size is null or household_size between 1 and 10)
    );

drop policy if exists "Service read" on public.user_profiles;
create policy "Service read" on public.user_profiles
    for all using (auth.role() = 'service_role');

-- Auswertung liest den jüngsten Stand je Installation.
create index if not exists user_profiles_install_idx
    on public.user_profiles (install_id, created_at desc);
