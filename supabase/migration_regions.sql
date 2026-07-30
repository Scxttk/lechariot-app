-- Le Chariot – Migration: On-Demand-Regionen (Phase 2.5)

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

alter table public.offers add column if not exists region text;

update public.offers set region = '01219' where region is null;

alter table public.offers drop constraint if exists offers_market_product_valid_from_key;
create unique index if not exists offers_market_product_valid_region_key
    on public.offers (market, product, valid_from, region);

create index if not exists offers_region_idx on public.offers (region);

insert into public.regions (plz) values ('01219') on conflict do nothing;
