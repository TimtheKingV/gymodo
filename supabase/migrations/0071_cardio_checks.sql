-- Cardio abhaken, Trainingsplan-Wochenplan: pro Mitglied und Kalendertag hoechstens
-- eine Zeile "Cardio erledigt". Der Tag ist der Kalendertag des Mitglieds (die App
-- bestimmt ihn in der Studio-Zeitzone), deshalb date und kein timestamptz.
--
-- Wie training_profiles (0060): kein studio_id, keine Staff-Klausel, nur das
-- Mitglied selbst liest, setzt und nimmt zurueck. Kein Update -- eine Zeile
-- hat nichts zu aendern, abhaken heisst einfuegen, zuruecknehmen loeschen.

create table public.cardio_checks (
  user_id    uuid not null references auth.users (id) on delete cascade,
  day        date not null,
  created_at timestamptz not null default now(),
  primary key (user_id, day)
);

alter table public.cardio_checks enable row level security;
alter table public.cardio_checks force  row level security;

create policy cardio_checks_select_own on public.cardio_checks
  for select to authenticated using (user_id = (select auth.uid()));
create policy cardio_checks_insert_own on public.cardio_checks
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy cardio_checks_delete_own on public.cardio_checks
  for delete to authenticated using (user_id = (select auth.uid()));
