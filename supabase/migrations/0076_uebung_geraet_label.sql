-- Geraete-Etikett an der Uebung (docs/superpowers/plans/2026-11-22-katalog-glattziehen.md, Etappe 1).
--
-- Uebungsnamen im Gymtavo-Katalog nennen das Geraet nicht mehr ("Bizepscurl"
-- statt "Kurzhantel-Bizepscurl"). Damit gleichnamige Uebungen unterscheidbar
-- bleiben, zeigt die App daneben ein kurzes Etikett des Geraetetyps
-- ("Kurzhantel", "Kabelzug"). Es steht an der Uebung selbst, damit jede Stelle,
-- die eine Uebung liest, es ohne Umweg ueber den Geraetetyp bekommt.
--
-- Der Katalogimport fuellt die Spalte aus equipment[].label der Katalogdatei.
-- Eigene Studio-Uebungen bleiben null: dort gibt es kein Etikett.
-- Keine neue Policy: die Spalte erbt die Lesezugriffe von exercises.

alter table public.exercises
  add column geraet_label text;

alter table public.exercises
  add constraint exercises_geraet_label_nicht_leer
  check (geraet_label is null or length(btrim(geraet_label)) > 0);
