-- ============================================================
-- Smart Shop – Migration: Rückmeldungen zu abgelehnten Treffern
-- Neue Tabelle `match_feedback`. Idempotent – kann gefahrlos
-- erneut laufen. Berührt den eingefrorenen Rust-Import nicht.
-- ============================================================
--
-- Wozu: Wer einen Treffer weglegt, kann sagen warum. Daraus wird das
-- Matching-Wörterbuch gepflegt (docs/matching-woerterbuch.json im Backend-Repo).
-- Die Auswahloption trägt die eigentliche Information, nicht der Freitext:
--
--   wrong_product   -> Wort auf die block-Liste des Begriffs
--   wrong_variant   -> block, oder ein neuer feinerer Begriff mit eigenem exact
--   wrong_size      -> KEINE Wörterbuchänderung (Mengenproblem)
--   personal_taste  -> KEINE Wörterbuchänderung (Vorliebe) – nur zählen
--   other           -> Freitext lesen
--
-- Dieselben zwei Entscheidungen wie bei `user_profiles`:
--
-- 1) APPEND-ONLY. Jede Ablehnung ist eine neue Zeile; nichts wird überschrieben.
--
-- 2) INSERT-Policy, aber KEINE SELECT-Policy für anon. Die App schreibt und
--    liest nie zurück — mit dem anon key sind fremde Rückmeldungen unerreichbar.
--    Ausgewertet wird über service_role.
--
-- `comment` ist vom Nutzer geschriebener Freitext. Die App sagt im Sheet, dass
-- er übertragen wird, und schneidet bei 500 Zeichen ab; der Check unten ist die
-- zweite Grenze, damit ein fremder anon key hier nichts ablegen kann.

create table if not exists public.match_feedback (
    id            bigint generated always as identity primary key,
    install_id    uuid        not null,
    created_at    timestamptz not null default now(),
    -- Das Wort von der Einkaufsliste, das den Treffer erzeugt hat.
    query         text        not null,
    product_title text        not null,
    market        text        not null,
    match_kind    text        not null,
    reason        text        not null,
    comment       text
);

alter table public.match_feedback enable row level security;

-- App darf Rückmeldungen anlegen (anon INSERT, MatchFeedbackStore.submit)
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

-- Die Auswertung gruppiert nach (Suchbegriff, Produkttitel) und wirft
-- personal_taste vorher weg — siehe docs/feedback-auswertung.md.
create index if not exists match_feedback_query_idx
    on public.match_feedback (query, product_title);
create index if not exists match_feedback_created_idx
    on public.match_feedback (created_at desc);
