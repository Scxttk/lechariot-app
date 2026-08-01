-- ============================================================
-- Le Chariot – Migration v25: Auskunft und Löschung selbst auslösen
-- Zwei Funktionen, keine neue Tabelle. Idempotent.
-- ============================================================
--
-- Wozu: Die Datenschutzerklärung verspricht Auskunft und Löschung über die
-- Installations-ID. Seit dem 2026-07-31 steht die ID in der App — auslösen
-- konnte der Nutzer damit aber nichts, er konnte sie nur abschreiben und eine
-- Mail schicken. Ein halbes Versprechen ([UI-4], 2026-08-01).
--
-- Warum RPC und nicht DELETE über PostgREST:
--
--   `user_profiles`, `match_feedback` und `branch_requests` haben eine
--   INSERT-Policy und sonst nichts. Ein anon-DELETE darauf schlägt **nicht
--   fehl** — RLS filtert die Zeilen weg und PostgREST antwortet mit 204. Die
--   App bekäme also Erfolg gemeldet und es wäre nichts gelöscht. Genau die
--   Fehlerklasse, an der dieses Projekt schon dreimal hing: nichts schlägt
--   fehl, es sagt nur etwas Falsches mit voller Überzeugung.
--
--   Deshalb `security definer` mit fest verdrahteter `install_id`-Bedingung.
--   Die Funktion kann genau eine Installation anfassen — die, deren ID
--   mitgeschickt wird —, und sie **gibt zurück, was wirklich verschwunden
--   ist**, nicht was verschwinden sollte.
--
-- Bedrohungsmodell, ausdrücklich: Wer eine fremde install_id kennt, kann
-- deren Zeilen löschen und lesen. Das ist dieselbe Auskunft, mit der ein
-- Mensch heute per Mail eine Löschung verlangen würde — die ID *ist* der
-- Ausweis. Sie ist eine Zufalls-UUID, steht nur auf dem Gerät und wird
-- nirgends neben einem Namen geführt.
--
-- Eine SELECT/DELETE-Policy für anon wäre der falsche Weg: `using (true)`
-- gäbe den ganzen Bestand frei, und eine Bedingung auf die eigene ID lässt
-- sich ohne Anmeldung in RLS gar nicht ausdrücken.
--
-- ZWEI TABELLEN, NICHT DREI. Am 2026-08-01 an den Migrationen nachgesehen:
-- `install_id` steht nur in `user_profiles` und `match_feedback`.
-- `branch_requests` (Schlüssel `market_id`, v14), `area_requests` (Schlüssel
-- `market_id`, v19/v22) und `regions` (Schlüssel `plz`) sind **geteilt** —
-- eine Zeile je Laden bzw. je Gegend, für alle Tester dieselbe. Dort steht,
-- *welcher* Laden geholt werden soll, nicht *wer* ihn wollte; es gibt darin
-- keinen Personenbezug zu löschen, und ein Löschen nähme anderen Testern die
-- Angebote weg. Der Backlog-Eintrag [UI-4] nannte alle drei — das stimmt für
-- `branch_requests` nicht.

-- Löscht alles zu einer Installation und sagt, wie viel es war.
create or replace function public.delete_installation(p_install_id uuid)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
    v_profiles integer;
    v_feedback integer;
begin
    if p_install_id is null then
        raise exception 'install_id fehlt';
    end if;

    delete from public.user_profiles where install_id = p_install_id;
    get diagnostics v_profiles = row_count;

    delete from public.match_feedback where install_id = p_install_id;
    get diagnostics v_feedback = row_count;

    return json_build_object('profiles', v_profiles, 'feedback', v_feedback);
end;
$$;

-- Gibt zurück, was zu einer Installation auf dem Server liegt.
create or replace function public.export_installation(p_install_id uuid)
returns json
language sql
security definer
set search_path = public
as $$
    select json_build_object(
        'install_id', p_install_id,
        'exported_at', now(),
        'user_profiles', coalesce(
            (select json_agg(to_jsonb(p) - 'id' order by p.created_at)
             from public.user_profiles p where p.install_id = p_install_id), '[]'::json),
        'match_feedback', coalesce(
            (select json_agg(to_jsonb(f) - 'id' order by f.created_at)
             from public.match_feedback f where f.install_id = p_install_id), '[]'::json)
    );
$$;

revoke all on function public.delete_installation(uuid) from public;
revoke all on function public.export_installation(uuid) from public;
grant execute on function public.delete_installation(uuid) to anon;
grant execute on function public.export_installation(uuid) to anon;
