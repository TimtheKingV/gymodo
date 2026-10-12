-- Testnotiz 12.10., #1-#5: Kategorie-Kacheln in "Geraet waehlen" und ein
-- zusammengelegter Kabelzug.
--
-- equipment_group ist die Kachel, unter der ein Gymtavo-Typ in der
-- Member-App steht. Nullbar, weil ein Studiomodell keine eigene Gruppe
-- traegt: es erbt die seines Gymtavo-Typs (catalog_model_id), sonst
-- entscheidet die Kategorie. Bewusst getrennt von category -- die traegt
-- im Portal die Einheiten, und eine Hantel bleibt dort "kraft".
--
-- retired loest einen Typ ab, der in einem anderen aufgegangen ist. Der
-- Katalogimport loescht nie (Spec 9.1): Saetze, Vorschlaege und Produkte
-- zeigen mit "on delete restrict" auf die Zeile. Abgeloest heisst: in
-- Listen ausgeblendet, fuer alte Saetze und Bloecke weiter aufloesbar.
-- Wie category braucht keine der Spalten einen Grant (0047).
alter table public.equipment_models
  add column equipment_group text
    constraint equipment_models_equipment_group_check
    check (equipment_group in ('geraete', 'freihantel', 'kabelzug', 'cardio', 'eigengewicht', 'kettlebell', 'gummiband')),
  add column retired boolean not null default false;
