-- Ein Aushang am Eingang traegt denselben Tokenraum und dieselbe URL wie ein
-- Geraeteaufkleber -- nur zeigt er auf kein Geraet. Eine Spalte statt einer
-- zweiten Tabelle: eine Umbenennung von machine_tags zoege sechs Migrationen,
-- zwei Policies, zwei Indizes und resolve_tag_fallback hinter sich her.
create type public.tag_kind as enum ('machine', 'studio');

alter table public.machine_tags
  add column kind public.tag_kind not null default 'machine';

comment on column public.machine_tags.kind is
  'machine = Aufkleber am Geraet, studio = Aushang am Eingang. Der Tabellenname stammt aus 0002, als es nur die erste Sorte gab.';

-- 0008 verlangte: ein aktiver Tag haengt an einem Geraet. Ein Aushang hat
-- keines und muss aktiv sein. Die Regel faellt nicht ersatzlos -- sonst
-- verliert der Geraetefall seinen Schutz --, sie differenziert nach Sorte.
alter table public.machine_tags
  drop constraint machine_tags_active_needs_machine;

alter table public.machine_tags
  add constraint machine_tags_machine_kind
    check (case kind
             when 'machine' then status <> 'active' or machine_id is not null
             when 'studio'  then machine_id is null
           end);
