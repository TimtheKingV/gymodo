-- on delete restrict statt set null: set null wuerde beim Loeschen eines
-- Geraets die machine_id revozierter Tags still auf NULL setzen. restrict
-- verhindert diesen automatischen Pfad -- es bewahrt die Historie aber NICHT
-- vollstaendig: wer ein Geraet wirklich loeschen will, muss machine_id vorher
-- von Hand nullen. Der vorgesehene Weg ist daher nicht Loeschen, sondern
-- machines.status = 'inactive'. Eine dauerhafte Loesung (eigene
-- Zuordnungshistorie statt nullbarem Zeiger) ist dem Folgeplan vorbehalten.
alter table public.machine_tags
  add constraint machine_tags_machine_id_fkey
    foreign key (machine_id) references public.machines (id) on delete restrict;

alter table public.machine_tags
  add constraint machine_tags_active_needs_machine
    check (status <> 'active' or machine_id is not null);
