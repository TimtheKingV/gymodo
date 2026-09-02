-- Aufgabe 4 (0027) gab tag_batches absichtlich keine einzige Policy -- richtig
-- fuer ein unverbundenes Studio, zu grob fuer ein verbundenes: die Tags-Seite
-- (Aufgabe 8) braucht Charge und Sorte fuer jede eigene Lieferung und jeden
-- eigenen Tag, und das Design (Tags.dc.html) zeigt "Charge 7"/"Charge 8" dem
-- Trainer seit jeher.
--
-- Sichtbar wird eine Charge nur ueber eine Verbindung, die das aufrufende Konto
-- bereits nachweislich hat: eine Lieferung an das eigene Studio, oder ein Tag,
-- der dem eigenen Studio bereits gehoert. Ein Studio ohne solche Verbindung
-- sieht weiterhin nichts -- das schuetzt genau das, was 0027 schuetzen wollte.
create policy tag_batches_select_connected on public.tag_batches
  for select to authenticated
  using (
    exists (
      select 1 from public.tag_shipments ts
       where ts.batch_id = tag_batches.id
         and public.is_studio_staff(ts.studio_id)
    )
    or exists (
      select 1 from public.machine_tags mt
       where mt.batch_id = tag_batches.id
         and mt.studio_id is not null
         and public.is_studio_staff(mt.studio_id)
    )
  );
