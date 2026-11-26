-- Ein Flow-Schritt kann optional auf eine Uebung im Katalog verweisen. Zweck: die App kann zu
-- dem Schritt das Video bzw. die Kameraerkennung der Uebung anbieten. Ohne Verweis (null)
-- verhaelt sich der Schritt wie bisher. Wird die Uebung geloescht, bleibt der Schritt stehen
-- und verliert nur den Verweis. Keine neue Policy: Lesen und Schreiben regeln die Policies
-- aus 0078/0079 fuer die ganze Zeile.

alter table public.flow_steps
  add column exercise_id uuid null references public.exercises(id) on delete set null;

comment on column public.flow_steps.exercise_id is
  'Optionaler Verweis auf die Katalog-Uebung, deren Video/Kamera zu diesem Schritt gehoert.';
