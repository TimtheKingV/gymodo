-- Testnotiz 12.10. abends, #3: wo das Rad ohne Historie steht.
--
-- Bisher startete jedes Rad am Minimum, an den Gymtavo-Typen also bei
-- 0 kg. load_start ist ein Ausgangspunkt je Geraet, keine Empfehlung je
-- Person: eine Beinpresse beginnt hoeher als ein Bizepscurl. Gesetzt vom
-- Katalogimport an den Gymtavo-Typen. Nullbar, weil ein Studiomodell
-- keinen eigenen Wert traegt: es erbt den seines Gymtavo-Typs bei gleicher
-- Einheit (bootstrap.ts, startDesModells), sonst gilt das Minimum.
-- Wie load_min braucht die Spalte keinen eigenen Grant (0047).
alter table public.equipment_models
  add column load_start numeric
    constraint equipment_models_load_start_range
    check (load_start is null or (load_start >= load_min and (load_max is null or load_start <= load_max)));
