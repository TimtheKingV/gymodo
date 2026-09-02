-- Tags entstehen chargenweise beim Lieferanten und werden studioweise
-- ausgeliefert. Zwischen beidem liegt die Halde: Zeilen, die es gibt, aber noch
-- keinem Studio gehoeren.
--
-- Die Halde liegt in machine_tags selbst, nicht in einer eigenen Tabelle. Der
-- naheliegende Gegenentwurf -- tag_batch_items, aus dem beim Versand kopiert
-- wird -- haette denselben Token an zwei Orten und eine zweite Unique-Insel
-- ueber den Tokenraum, die auseinanderlaufen kann. Eine nullbare
-- Fremdschluesselspalte ist billiger zu bewachen als zwei Tabellen, die
-- dasselbe behaupten.
--
-- Spec: docs/superpowers/specs/2026-09-01-tag-lieferung-design.md, Abschnitt 2.

-- Eine Charge ist ein Herstellungslos: N Aufkleber oder N Schilder, in einem
-- Zug gedruckt. Sie ist ein Betreibergegenstand -- kein Studio hat ein Wort
-- dazu. Deshalb bekommt die Tabelle keine einzige Policy: mit aktivem RLS und
-- ohne Policy liefert sie jedem authenticated-Konto null Zeilen, und nur
-- service_role (rolbypassrls) erreicht sie. Das ist die Absicherung, nicht die
-- Grant-Lage -- auto_expose_new_tables ist auf dem Vorgabewert.
create table public.tag_batches (
  id          uuid primary key default gen_random_uuid(),
  code        text not null unique,
  kind        public.tag_kind not null,
  quantity    integer not null check (quantity > 0),
  supplier    text,
  ordered_on  date,
  scrapped_at timestamptz,
  created_at  timestamptz not null default now()
);

alter table public.tag_batches enable row level security;
alter table public.tag_batches force  row level security;

-- Eine Lieferung ist eine Zahl, keine Liste. Welche hundert Aufkleber in der
-- Kiste lagen, weiss niemand -- ein Geraetetag lernt sein Studio erst beim Scan
-- vor dem Geraet. Diese Zeile traegt allein die Auskunft auf der Tags-Seite:
-- "Lieferung vom 12. August * 100 Tags".
--
-- on delete restrict auf beiden Fremdschluesseln: eine Lieferung ist ein
-- Vorgang der Vergangenheit. Ein Studio wird stillgelegt, nicht geloescht --
-- dieselbe Linie wie bei machine_tags_machine_id_fkey aus 0008.
create table public.tag_shipments (
  id         uuid primary key default gen_random_uuid(),
  batch_id   uuid not null references public.tag_batches (id) on delete restrict,
  studio_id  uuid not null references public.studios     (id) on delete restrict,
  quantity   integer not null check (quantity > 0),
  shipped_on date not null default current_date,
  note       text,
  created_at timestamptz not null default now()
);

create index on public.tag_shipments (studio_id);

alter table public.tag_shipments enable row level security;
alter table public.tag_shipments force  row level security;

-- Nur lesen, und nur das eigene Studio. Angelegt wird eine Lieferung vom
-- Betreiberskript ueber service_role; im Portal gibt es dafuer keinen Weg.
create policy tag_shipments_select on public.tag_shipments
  for select to authenticated
  using (public.is_studio_staff(studio_id));

-- 0026 hat die Tabelle geleert. Falls zwischen beiden Migrationen doch Zeilen
-- entstanden sind, koennen sie keine Charge tragen -- und ein Tag ohne Charge
-- gibt es ab hier nicht mehr.
delete from public.machine_tags;

-- studio_id wird nullbar: das ist die Halde. Gefahrlos, weil is_studio_member
-- und is_studio_staff fuer null beide false liefern (m.studio_id = null trifft
-- nie zu) -- eine studiolose Zeile ist damit fuer jedes authenticated-Konto
-- unsichtbar, ohne dass eine einzige Policy sich aendert.
--
-- batch_index ist die auf dem Erzeugnis aufgedruckte laufende Nummer. Ohne sie
-- hat "Sperren" auf der Tags-Seite kein Ziel: ein Aushangschild hat kein
-- Geraet, ueber das es sich benennen liesse, und einen Ort hat nie jemand
-- eingegeben.
alter table public.machine_tags
  alter column studio_id drop not null,
  add column batch_id    uuid    not null references public.tag_batches (id) on delete restrict,
  add column batch_index integer not null check (batch_index >= 1);

alter table public.machine_tags
  add constraint machine_tags_batch_index_key unique (batch_id, batch_index);

create index on public.machine_tags (batch_id);

-- Vier Aussagen in einer Zeile: eine Zeile ohne Studio hat kein Geraet, ist nie
-- aktiv, und darf trotzdem revoked werden -- verlorene Packung, Fehldruck vor
-- dem Versand. Und weil sie nie aktiv sein kann, bleibt die Annahme
-- "studio_id: string" in getTagContext wahr, ohne dass die Datei sich aendert.
--
-- machine_tags_machine_kind aus 0022 bleibt daneben unveraendert gueltig.
alter table public.machine_tags
  add constraint machine_tags_halde
    check (studio_id is not null
           or (status in ('unassigned', 'revoked') and machine_id is null));

-- 0026 konnte die beiden neuen Spalten nicht nennen, es gab sie dort noch
-- nicht. Eine Spaltenliste ist eine Aufzaehlung, keine Ausnahme: ohne diese
-- Erneuerung kann die Tags-Seite "Charge 7" nicht anzeigen.
grant select (id, studio_id, machine_id, token_hash, status, kind,
              batch_id, batch_index, created_at, revoked_at)
  on public.machine_tags to authenticated;
