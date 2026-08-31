-- Bisher kaskadierte das Loeschen einer Uebung ueber
-- equipment_model_exercises bis auf instruction_assets durch. Wer eine Uebung
-- aus dem Katalog nahm, loeschte damit stillschweigend die Videozeile -- die
-- Datei im Bucket blieb als Waise liegen, ohne dass irgendwo stand, wozu sie
-- gehoert hatte. Das Video ist Studioarbeit: aufgenommen, hochgeladen,
-- kontrolliert. Es darf nicht als Nebenwirkung verschwinden.
--
-- restrict statt cascade, dieselbe Entscheidung wie bei machines/machine_tags
-- in 0008: der Loeschpfad wird nicht bequemer gemacht, sondern ausdruecklich.
-- Wer die Uebung entfernen will, loescht zuerst das Video -- und weiss damit,
-- dass er es tut. Die Garantie liegt im Schema, nicht im Editor: auch eine
-- Migration oder ein spaeterer Endpoint kommt nicht daran vorbei.
alter table public.instruction_assets
  drop constraint instruction_assets_equipment_model_exercise_id_fkey;

alter table public.instruction_assets
  add constraint instruction_assets_equipment_model_exercise_id_fkey
    foreign key (equipment_model_exercise_id)
    references public.equipment_model_exercises (id) on delete restrict;
