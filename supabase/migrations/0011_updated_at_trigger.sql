-- updated_at existiert auf studios, profiles, equipment_models, exercises
-- und machines, wurde aber von keinem Trigger fortgeschrieben -- Clients
-- konnten (ueber ihre UPDATE-Policies) sogar einen beliebigen eigenen Wert
-- hineinschreiben. Eine gemeinsame Triggerfunktion setzt den Wert serverseitig
-- bei jedem UPDATE und ueberschreibt dabei jeden vom Client mitgeschickten
-- Wert.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger set_updated_at before update on public.studios
  for each row execute function public.set_updated_at();

create trigger set_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();

create trigger set_updated_at before update on public.equipment_models
  for each row execute function public.set_updated_at();

create trigger set_updated_at before update on public.exercises
  for each row execute function public.set_updated_at();

create trigger set_updated_at before update on public.machines
  for each row execute function public.set_updated_at();
