-- Le Chariot – Migration v15: gewählte Filialen im Profil

alter table public.user_profiles
    add column if not exists branch_ids text[] not null default '{}';

drop policy if exists "Anon insert profile" on public.user_profiles;
create policy "Anon insert profile" on public.user_profiles
    for insert with check (
        install_id is not null
        and (plz is null or plz ~ '^[0-9]{5}$')
        and (household_size is null or household_size between 1 and 10)
        and coalesce(array_length(branch_ids, 1), 0) <= 10
    );
