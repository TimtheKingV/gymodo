-- Koerpergewicht als Verlauf, Spec 2026-09-13-ziele-und-fortschritt-design.md
-- Abschnitt 3.2. Die erste Tabelle des Schemas mit Gesundheitsdaten im
-- Sinn von Art. 9 DSGVO -- und deshalb die erste mit DREI bewussten
-- Abweichungen von den Trainingstabellen:
--
--  1. KEIN studio_id. Jede Trainingstabelle seit 0012 haengt am Studio,
--     und wer austritt, verliert den Blick auf seine dortige Historie
--     (0033). Das Koerpergewicht gehoert zur Person, nicht zur Halle:
--     wer das Studio wechselt, nimmt seine Kurve mit.
--
--  2. KEINE Staff-Klausel, KEINE Mitgliedschaftspruefung -- und keine
--     Oeffnung ueber eine SECURITY-DEFINER-Funktion, auch nicht als Summe.
--     studio_overview (0034) ist die einzige Stelle, an der Personal
--     Trainingsdaten aggregiert sieht; Koerperdaten bekommen keine solche
--     Stelle. Wer das je aendert, aendert eine Entscheidung, keine
--     Kleinigkeit.
--
--  3. Ein Wert je Tag. Zwei Wiegungen am selben Tag sind keine zwei
--     Messpunkte, sondern eine Korrektur -- der Schreibweg ist ein
--     Upsert auf (user_id, measured_on). measured_on ist ein date, kein
--     Zeitpunkt: gewogen wird morgens, der Tag ist die Wahrheit, die
--     Uhrzeit Rauschen. Der Client liefert den Ortstag; der Server
--     rechnet keine Zeitzone.

create table public.body_measurements (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  measured_on date not null,
  weight_kg   numeric(5,1) not null,
  created_at  timestamptz not null default now(),
  constraint body_measurements_weight_range
    check (weight_kg between 20.0 and 400.0),
  constraint body_measurements_one_per_day
    unique (user_id, measured_on)
);

-- Kein zusaetzlicher Index: der Unique-Constraint body_measurements_one_per_day
-- legt bereits einen Btree auf (user_id, measured_on) an, der geordnete
-- Scans in beide Richtungen bedient (getMeasurements liest absteigend).

alter table public.body_measurements enable row level security;
alter table public.body_measurements force  row level security;

create policy body_measurements_select_own on public.body_measurements
  for select to authenticated
  using (user_id = (select auth.uid()));

create policy body_measurements_insert_own on public.body_measurements
  for insert to authenticated
  with check (user_id = (select auth.uid()));

create policy body_measurements_update_own on public.body_measurements
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy body_measurements_delete_own on public.body_measurements
  for delete to authenticated
  using (user_id = (select auth.uid()));
