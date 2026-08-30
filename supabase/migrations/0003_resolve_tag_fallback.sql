-- Loest den Service-Role-Key im oeffentlichen Web-Fallback ab (siehe M0-
-- Abschlussreview, Ruling zu Finding 2). Liefert ausschliesslich eine
-- machine_tag_id fuer aktive Tags -- niemals Personendaten, niemals mehr
-- Spalten als der aufrufende Client ohnehin schon kennen darf.
create or replace function public.resolve_tag_fallback(p_token_hash text)
returns table (machine_tag_id uuid)
language sql
security definer
set search_path = public, pg_temp
stable
as $$
  select id
  from public.machine_tags
  where token_hash = p_token_hash
    and status = 'active';
$$;

revoke all on function public.resolve_tag_fallback(text) from public;
grant execute on function public.resolve_tag_fallback(text) to anon;
