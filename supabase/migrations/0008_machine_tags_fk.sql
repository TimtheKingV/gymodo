-- on delete restrict, nicht set null: ein gelöschtes Geraet wuerde sonst bei
-- revozierten Tags die machine_id stillschweigend auf NULL setzen und damit
-- die fachliche Historie zerstoeren (welcher Tag hing an welchem Geraet), und
-- bei aktiven Tags mit einem kryptischen Verstoss gegen die Check-Constraint
-- unten abbrechen. Restrict macht die Regel explizit: bevor ein Geraet
-- geloescht werden kann, muessen seine Tags bewusst umgehaengt oder entfernt
-- werden. Konsistent mit machines.equipment_model_id (ebenfalls restrict).
alter table public.machine_tags
  add constraint machine_tags_machine_id_fkey
    foreign key (machine_id) references public.machines (id) on delete restrict;

alter table public.machine_tags
  add constraint machine_tags_active_needs_machine
    check (status <> 'active' or machine_id is not null);
