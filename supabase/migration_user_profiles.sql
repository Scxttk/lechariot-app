-- Le Chariot – Migration: Nutzer-Profile aus dem Onboarding

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

create index if not exists user_profiles_install_idx
    on public.user_profiles (install_id, created_at desc);
