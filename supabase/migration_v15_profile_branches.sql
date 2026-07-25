-- ============================================================
-- Smart Shop – Migration v15: gewählte Filialen im Profil
-- Erweitert `user_profiles` um `branch_ids`. Idempotent.
-- ============================================================
--
-- ACHTUNG: Das ist eine bewusste Umkehr. Die ursprüngliche Migration schreibt
-- ausdrücklich „Nicht enthalten und bewusst nie übertragen: Vorname,
-- Einkaufsliste und die gewählten Filialen". Vorname und Einkaufsliste
-- bleiben es auch — nur die Filialen kommen dazu, damit sich auswerten lässt,
-- welche Läden Nutzer tatsächlich wählen (und damit, welche Ketten und
-- Gebiete das Verzeichnis überhaupt braucht).
--
-- Was das für die Pseudonymität heißt, offen gesagt: Eine Filial-ID ist
-- genauer als eine PLZ. Wer drei Filialen wählt, ist damit auf einen
-- Stadtteil festgelegt. Der Abstand zum bisherigen Stand ist trotzdem
-- kleiner, als es klingt — `plz` steht seit jeher in dieser Tabelle, und drei
-- Filialen derselben PLZ verraten wenig mehr als die PLZ selbst. Ein
-- Personenbezug entsteht daraus nicht: `install_id` ist eine Zufalls-UUID der
-- Installation, aus keiner Geräte-ID abgeleitet, und es gibt weiterhin keine
-- SELECT-Policy für anon.
--
-- Was NICHT passiert: Die Spalte wird nicht rückwirkend gefüllt. Bestehende
-- Zeilen behalten '{}' — sie sind ein Schnappschuss ihres Zeitpunkts, und die
-- Tabelle ist append-only.

alter table public.user_profiles
    add column if not exists branch_ids text[] not null default '{}';

-- INSERT-Policy nachziehen: Ohne die Ergänzung würde die Spalte zwar
-- existieren, aber jede Zeile mit unbegrenzt vielen IDs durchgehen. Zehn ist
-- dieselbe Grenze, die die App für Regionen kennt (RegionStore.maxRegions) —
-- wer mehr Läden wählt, wählt keine Läden mehr aus, sondern lädt eine Liste
-- hoch.
drop policy if exists "Anon insert profile" on public.user_profiles;
create policy "Anon insert profile" on public.user_profiles
    for insert with check (
        install_id is not null
        and (plz is null or plz ~ '^[0-9]{5}$')
        and (household_size is null or household_size between 1 and 10)
        and coalesce(array_length(branch_ids, 1), 0) <= 10
    );
