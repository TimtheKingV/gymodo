-- Katalogfeld plan.vorschlag (Katalog Plan-Merkmale, docs/superpowers/plans/2026-11-16-katalog-plan-merkmale.md, E3).
--
-- Seit P4 darf das Mitglied jede Uebung mit Plan-Merkmalen frei hinzufuegen und
-- tauschen; dafuer bekommen alle Katalog-Uebungen plan_baustein/plan_typ/plan_bereiche.
-- Der Generator soll trotzdem nicht alles vorschlagen (etwa Langhantel-Kniebeuge oder
-- Kreuzheben fuer Einsteiger). plan_vorschlag = false heisst: waehlbar und tauschbar,
-- aber nie Generator-Kandidat. Der Filter steht im Generator (Domain, Regeln 1.5.0),
-- nicht in SQL; die Schreibwege (Tausch, Beschwerden-Check) lesen die Spalte nicht.
--
-- Default true: bestehende Zeilen bleiben, wie sie sind; der Katalogimport setzt false.
-- Keine neue Policy: die Spalte erbt die Lesezugriffe von exercises.

alter table public.exercises
  add column plan_vorschlag boolean not null default true;
