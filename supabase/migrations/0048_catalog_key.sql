-- Gymtavo-Katalog Etappe 2: Import aus Datei, Spec
-- 2026-10-06-gymtavo-katalog-offener-zugang-design.md, Abschnitt 9.1.
--
-- Der Import gleicht catalog/gymtavo.json mit dem Gymtavo-Studio ab. Er
-- braucht eine Identitaet, die nicht die UUID ist: die Datei kennt keine
-- UUIDs, und ein umbenannter Geraetetyp muss derselbe Datensatz bleiben,
-- weil Saetze und Studio-Zuordnungen auf ihn zeigen.

-- Ein echter Unique-Constraint statt eines Teilindex "where catalog_key is
-- not null": PostgREST-Upserts (on_conflict) brauchen einen Constraint oder
-- einen Index ohne Bedingung. NULL kollidiert in Postgres ohnehin nicht --
-- von Hand angelegte Katalogzeilen und alle Studiozeilen bleiben frei.
--
-- Kein Zwang auf das Gymtavo-Studio: ein Studio, das seinem eigenen Modell
-- einen Schluessel gibt, beruehrt den Katalog nicht, weil die Eindeutigkeit
-- je Studio gilt und der Import nur das Gymtavo-Studio liest.
alter table public.equipment_models
  add column catalog_key text
    constraint equipment_models_catalog_key_format
    check (catalog_key ~ '^[a-z0-9_]+$'),
  add constraint equipment_models_catalog_key_unique
    unique (studio_id, catalog_key);

alter table public.exercises
  add column catalog_key text
    constraint exercises_catalog_key_format
    check (catalog_key ~ '^[a-z0-9_]+$'),
  add constraint exercises_catalog_key_unique
    unique (studio_id, catalog_key);
