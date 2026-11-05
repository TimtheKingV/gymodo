-- Merkliste fuer Planuebungen (Spec Trainingsplan aus dem Katalog).
--
-- Das Mitglied merkt sich je Uebung:
--   nicht_vorhanden  -- "gibt es in meinem Studio nicht" (studio_id Pflicht; das
--                       Katalog-Studio steht fuer das Freie Training),
--   gefaellt_nicht   -- "mag ich nicht" (gilt studioweit, studio_id bleibt leer).
--
-- Es sind Angaben zur Person: RLS ist erzwungen, nur eigene Zeilen, kein
-- Update (aendern heisst loeschen und neu anlegen), anon hat keinen Zugriff.
-- Muster wie training_limits (0060).

create table public.plan_merkliste (
  user_id     uuid not null references auth.users (id) on delete cascade,
  exercise_id uuid not null references public.exercises (id) on delete cascade,
  art         text not null,
  studio_id   uuid references public.studios (id) on delete cascade,
  created_at  timestamptz not null default now(),
  constraint plan_merkliste_art check (art in ('nicht_vorhanden', 'gefaellt_nicht')),
  constraint plan_merkliste_studio_je_art check (
    (art = 'nicht_vorhanden' and studio_id is not null)
    or (art = 'gefaellt_nicht' and studio_id is null)
  )
);

-- Ein Ausdrucks-Index, weil ein Table-Constraint keinen coalesce(...) erlaubt;
-- die Null-UUID macht studio_id = null zu einem vergleichbaren Wert.
create unique index plan_merkliste_eindeutig on public.plan_merkliste
  (user_id, exercise_id, art, coalesce(studio_id, '00000000-0000-0000-0000-000000000000'::uuid));

alter table public.plan_merkliste enable row level security;
alter table public.plan_merkliste force  row level security;

revoke all on public.plan_merkliste from anon;
revoke all on public.plan_merkliste from public;
grant select, insert, delete on public.plan_merkliste to authenticated;

create policy plan_merkliste_select_own on public.plan_merkliste
  for select to authenticated using (user_id = (select auth.uid()));

create policy plan_merkliste_insert_own on public.plan_merkliste
  for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and (
      studio_id is null
      or public.is_studio_member(studio_id)
      or public.is_catalog_studio(studio_id)
    )
  );

create policy plan_merkliste_delete_own on public.plan_merkliste
  for delete to authenticated using (user_id = (select auth.uid()));
