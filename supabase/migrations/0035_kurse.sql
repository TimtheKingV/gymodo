-- Kurse, Spec 2026-09-03-kurse-design.md Abschnitt 3.
--
-- Drei Tabellen, und die dritte ist die einzige im ganzen Schema, deren
-- Zeilen niemandem gehoeren, bis sie jemand nimmt. Ein Kursplatz ist die
-- einzige Stelle des Produkts mit einem echten Wettlauf -- ueberall sonst
-- schreibt jeder auf seine eigenen Zeilen.
--
-- Diese Migration legt deshalb bewusst KEINE Funktion an und KEINEN
-- Schreibweg auf course_bookings. Beides kommt in 0036, und dazwischen
-- steht der Nebenlaeufigkeitstest.

create type public.course_session_status as enum ('planned', 'cancelled');
create type public.course_booking_status as enum ('booked', 'waitlisted', 'cancelled');

comment on type public.course_booking_status is
  'Englische Werte wie alle sieben bestehenden Enums des Schemas (studio_role, tag_status, machine_status, session_completed_reason, problem_reason, calibration_source, tag_kind). Die Vorabnotiz vom 30. August schrieb deutsche vor; die Projektregel "deutsche Bezeichner" trifft den Web-Layer, nicht das Schema. Die deutschen Woerter stehen in der Oberflaeche, an genau einer Stelle je Schicht.';

-- ---------------------------------------------------------------------
-- Vorlagen
-- ---------------------------------------------------------------------
--
-- "Kraftzirkel" ist die Vorlage, "Do 27.08. 18:00" der Termin. Ohne diese
-- Trennung pflegt ein Trainer jede Woche dieselbe Beschreibung neu.

create table public.course_templates (
  id                         uuid primary key default gen_random_uuid(),
  studio_id                  uuid not null references public.studios (id) on delete cascade,
  name                       text not null,
  description                text,
  default_duration_min       int  not null,
  default_capacity           int  not null,
  photo_path                 text,
  default_instructor_user_id uuid references auth.users (id) on delete set null,
  default_instructor_name    text,
  created_at                 timestamptz not null default now(),
  updated_at                 timestamptz not null default now(),
  constraint course_templates_name_not_blank
    check (length(btrim(name)) > 0),
  constraint course_templates_duration_range
    check (default_duration_min between 5 and 480),
  constraint course_templates_capacity_range
    check (default_capacity between 1 and 500)
);

comment on column public.course_templates.photo_path is
  'Angelegt, aber in diesem Bauabschnitt ohne Uploadweg (Spec Abschnitt 7). 0020 richtet equipment-photos und instruction-videos mit eigenem Pfadschema ueber storage_studio_id ein; ein Kursfoto braeuchte einen dritten Bucket samt vier Storage-Policies mit voller Testmatrix. Die Spalte kostet nichts und erspart die Migration.';

comment on column public.course_templates.default_instructor_user_id is
  'Die ZUORDNUNG -- welches Konto ist zustaendig. Angezeigt wird nie diese Spalte, sondern default_instructor_name (Spec Abschnitt 4). Was die Datenbank hier NICHT erzwingt: dass die Kennung auf Personal dieses Studios zeigt. Eine check-Constraint kann keine Unterabfrage, und ein Trigger dafuer waere eine fuenfte Funktion in einem Projekt, das gerade vier ohne gesetzten search_path als offenen Punkt fuehrt. Die Fachschicht prueft es beim Speichern. Das Restrisiko ist klein: das Feld wird nirgends angezeigt, es verraet nichts, und wer es faelschlich fuellen will, muesste eine fremde Kennung bereits kennen.';

comment on column public.course_templates.default_instructor_name is
  'Die ANZEIGE. Ist sie leer, steht auf dem Bildschirm kein Name -- nie die E-Mail-Adresse. profiles.display_name (0001) kaeme dafuer nicht in Frage: profiles_select_own gibt nur die eigene Zeile frei, und keine Zeile Produktivcode fuellt die Spalte.';

create index on public.course_templates (studio_id, name);

create trigger set_updated_at before update on public.course_templates
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------
-- Termine
-- ---------------------------------------------------------------------

create table public.course_sessions (
  id                 uuid primary key default gen_random_uuid(),
  studio_id          uuid not null references public.studios (id) on delete cascade,
  course_template_id uuid not null references public.course_templates (id) on delete restrict,
  starts_at          timestamptz not null,
  duration_min       int  not null,
  capacity           int  not null,
  room               text,
  instructor_user_id uuid references auth.users (id) on delete set null,
  instructor_name    text,
  status             public.course_session_status not null default 'planned',
  cancelled_at       timestamptz,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  constraint course_sessions_duration_range
    check (duration_min between 5 and 480),
  constraint course_sessions_capacity_range
    check (capacity between 1 and 500),
  -- Dieselbe Bauform wie workout_sessions_completion_consistent (0012):
  -- es soll keine abgesagten Termine ohne Zeitpunkt geben und keine
  -- Zeitpunkte ohne Absage.
  constraint course_sessions_cancellation_consistent
    check ((status = 'cancelled') = (cancelled_at is not null))
);

comment on column public.course_sessions.capacity is
  'Liegt am Termin, nicht an der Vorlage: ein Kurs im kleinen Raum hat weniger Plaetze als derselbe Kurs im grossen. Die Werte werden beim Anlegen aus der Vorlage KOPIERT, nicht verwiesen -- TerminAnlegen.dc.html schreibt die Folge selbst hin: "Aenderst du die Vorlage spaeter, bleiben diese 14 Termine unveraendert."';

comment on constraint course_sessions_cancellation_consistent on public.course_sessions is
  'Absage statt Loeschen: die Zeile bleibt stehen, damit angemeldete Mitglieder sehen, was passiert ist. Ein verschwundener Termin sieht aus wie ein Fehler in der App.';

-- Die Wochenabfrage ist der einzige Lesepfad, der zaehlt.
create index on public.course_sessions (studio_id, starts_at);
create index on public.course_sessions (course_template_id, starts_at);

create trigger set_updated_at before update on public.course_sessions
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------
-- Buchungen
-- ---------------------------------------------------------------------

create table public.course_bookings (
  id                uuid primary key,
  studio_id         uuid not null references public.studios (id) on delete cascade,
  course_session_id uuid not null references public.course_sessions (id) on delete cascade,
  user_id           uuid not null references auth.users (id) on delete cascade,
  status            public.course_booking_status not null,
  booked_at         timestamptz not null default clock_timestamp(),
  promoted_at       timestamptz,
  cancelled_at      timestamptz,
  created_at        timestamptz not null default now(),
  constraint course_bookings_cancellation_consistent
    check ((status = 'cancelled') = (cancelled_at is not null)),
  -- Wer nachgerueckt ist, steht nicht mehr auf der Liste.
  constraint course_bookings_promotion_consistent
    check (promoted_at is null or status <> 'waitlisted')
);

comment on column public.course_bookings.id is
  'Ohne Default, wie workout_sessions (0012). Die Kennung kommt vom Client, damit derselbe PUT zweimal denselben Platz ergibt -- Idempotenz strukturell statt als Mechanismus (M1-Spec 6.3). Ein Insert ohne id soll auffallen, nicht stillschweigend eine zweite Buchung anlegen.';

comment on column public.course_bookings.booked_at is
  'clock_timestamp(), nicht now(). now() steht innerhalb einer Transaktion still und liefert deren Startzeitpunkt; zwei Anmeldungen, die an derselben Zeilensperre anstehen, bekaemen damit eine Wartelistenreihenfolge nach Transaktionsbeginn statt nach Zuteilung -- wer eine Millisekunde frueher BEGONNEN hat, aber spaeter durch die Sperre kam, stuende vorn. clock_timestamp() laeuft weiter: wer zuerst durch die Sperre geht, steht zuerst auf der Liste.';

comment on column public.course_bookings.promoted_at is
  'Wann diese Buchung von der Warteliste nachgerueckt ist. Die Benachrichtigung dazu gibt es nicht (Spec Abschnitt 8) -- Push existiert nicht, und eine Transaktionsmail laege als Ausfallpunkt in der Stornotransaktion. Die Spalte kostet nichts und traegt zweierlei: die Oberflaeche kann "Du bist nachgerueckt" als Zustand zeigen, und eine spaetere Benachrichtigung hat einen Zeitpunkt, ohne dass es dafuer je eine zweite Migration braucht.';

-- Die zweite Verteidigungslinie gegen die Doppelbuchung. Die Funktion aus
-- 0036 gibt eine bestehende Buchung unveraendert zurueck, statt eine
-- zweite anzulegen; dieser Index sorgt dafuer, dass das auch dann gilt,
-- wenn jemand die Funktion einmal aendert und den Fall vergisst.
--
-- status <> 'cancelled' im where: wer storniert hat, darf sich erneut
-- anmelden, und das wird eine NEUE Zeile -- die Stornierung bleibt
-- stehen. Historie wird nicht durch ein stilles Update zerstoert
-- (Regelwerk M1-Spec Abschnitt 10).
create unique index course_bookings_one_per_member
  on public.course_bookings (course_session_id, user_id)
  where status <> 'cancelled';

-- Traegt beides: die Zaehlung innerhalb der Sperre und die Reihenfolge
-- der Warteliste.
create index on public.course_bookings (course_session_id, status, booked_at);

-- ---------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------

alter table public.course_templates enable row level security;
alter table public.course_templates force  row level security;
alter table public.course_sessions  enable row level security;
alter table public.course_sessions  force  row level security;
alter table public.course_bookings  enable row level security;
alter table public.course_bookings  force  row level security;

-- Mitglieder lesen: die Member-App braucht Name, Beschreibung und Termin.
create policy course_templates_select on public.course_templates
  for select to authenticated
  using (public.is_studio_member(course_templates.studio_id));

create policy course_templates_insert_staff on public.course_templates
  for insert to authenticated
  with check (public.is_studio_staff(course_templates.studio_id));

-- Die Bedingung steht auf beiden Seiten: ohne with check koennte ein
-- Trainer eine Zeile aus seinem Studio heraus-aendern.
create policy course_templates_update_staff on public.course_templates
  for update to authenticated
  using (public.is_studio_staff(course_templates.studio_id))
  with check (public.is_studio_staff(course_templates.studio_id));

create policy course_sessions_select on public.course_sessions
  for select to authenticated
  using (public.is_studio_member(course_sessions.studio_id));

create policy course_sessions_insert_staff on public.course_sessions
  for insert to authenticated
  with check (public.is_studio_staff(course_sessions.studio_id));

create policy course_sessions_update_staff on public.course_sessions
  for update to authenticated
  using (public.is_studio_staff(course_sessions.studio_id))
  with check (public.is_studio_staff(course_sessions.studio_id));

-- Kein Delete auf beiden: Absage statt Loeschen, und eine geloeschte
-- Vorlage naehme die Termine mit. Es gibt deshalb bewusst keine
-- Delete-Policy -- ohne sie greift RLS und der Loeschversuch trifft null
-- Zeilen.

-- Die Datenschutzgrenze aus 0033, fortgeschrieben fuer Kurse.
--
-- Mitglieder sehen ausschliesslich eigene Buchungen. Personal sieht die
-- Teilnehmerliste -- Portalspec Abschnitt 4 zaehlt "wer fuer einen
-- Kurstermin angemeldet ist" ausdruecklich zum Sichtbaren. Sie ist eine
-- Anwesenheitsliste, sie gehoert dem Studio, und fuer andere Mitglieder
-- ist sie unsichtbar.
create policy course_bookings_select on public.course_bookings
  for select to authenticated
  using (
    public.is_studio_member(course_bookings.studio_id)
    and (
      course_bookings.user_id = (select auth.uid())
      or public.is_studio_staff(course_bookings.studio_id)
    )
  );

-- KEINE Insert-, Update- und Delete-Policy auf course_bookings.
--
-- Das ist nicht Sparsamkeit, sondern die Voraussetzung dafuer, dass die
-- Zeilensperre aus 0036 ueberhaupt etwas wert ist. Mit einer
-- Insert-Policy koennte ein Mitglied per PostgREST direkt status='booked'
-- schreiben und an der Kapazitaet vorbeigehen -- die Sperre schuetzte
-- dann einen Weg, an dem ein zweiter, offener vorbeifuehrt.
--
-- Dieselbe Begruendung steht woertlich in 0030: "ein Insert-Recht auf
-- studio_memberships waere breiter als noetig".
--
-- Die Abwesenheit ist damit eine Zusicherung, und sie wird geprueft:
-- tests/integration/rls-kurse.test.ts, Block "die gepruefte Abwesenheit".
