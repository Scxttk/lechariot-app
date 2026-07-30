-- Le Chariot – Migration: Rückmeldungen zu abgelehnten Treffern

create table if not exists public.match_feedback (
    id            bigint generated always as identity primary key,
    install_id    uuid        not null,
    created_at    timestamptz not null default now(),
    query         text        not null,
    product_title text        not null,
    market        text        not null,
    match_kind    text        not null,
    reason        text        not null,
    comment       text
);

alter table public.match_feedback enable row level security;

drop policy if exists "Anon insert feedback" on public.match_feedback;
create policy "Anon insert feedback" on public.match_feedback
    for insert with check (
        install_id is not null
        and length(query) between 1 and 100
        and length(product_title) between 1 and 300
        and length(market) between 1 and 100
        and match_kind in ('direct', 'category')
        and reason in ('wrong_product', 'wrong_variant', 'wrong_size', 'personal_taste', 'other')
        and (comment is null or length(comment) <= 500)
    );

drop policy if exists "Service read feedback" on public.match_feedback;
create policy "Service read feedback" on public.match_feedback
    for all using (auth.role() = 'service_role');

create index if not exists match_feedback_query_idx
    on public.match_feedback (query, product_title);
create index if not exists match_feedback_created_idx
    on public.match_feedback (created_at desc);
