-- Der Fallback muss zwei Faelle unterscheiden koennen, ohne dafuer eine
-- zweite Abfrage und ohne dafuer Leserecht auf studios. Der Studioname ist
-- Studioinhalt, kein Personenbezug -- er steht ohnehin auf jedem Aushang.
--
-- Die fuenf Spalten aus 0021 bleiben unveraendert stehen. Neu sind nur kind
-- und studio_name; die Geraeteseite und ihr Integrationstest lesen weiter,
-- was sie vorher lasen.
drop function if exists public.resolve_tag_fallback(text);

create function public.resolve_tag_fallback(p_token_hash text)
returns table (
  machine_tag_id uuid,
  kind           public.tag_kind,
  studio_name    text,
  machine_label  text,
  model_name     text,
  photo_path     text,
  exercises      jsonb
)
language sql
security definer
set search_path = public, pg_temp
stable
as $$
  select
    t.id, t.kind, s.name, m.label, em.name, em.photo_path,
    coalesce(
      (select jsonb_agg(jsonb_build_object('name', e.name, 'video_path', video.storage_path)
                 order by eme.sort_order, e.name)
         from public.equipment_model_exercises eme
         join public.exercises e on e.id = eme.exercise_id
         left join lateral (
           select ia.storage_path from public.instruction_assets ia
           where ia.equipment_model_exercise_id = eme.id
           order by ia.created_at desc, ia.id desc limit 1
         ) video on true
        where eme.equipment_model_id = em.id),
      '[]'::jsonb)
  from public.machine_tags t
  join public.studios s on s.id = t.studio_id
  left join public.machines m on m.id = t.machine_id
  left join public.equipment_models em on em.id = m.equipment_model_id
  where t.token_hash = p_token_hash
    and t.status = 'active'
    and (t.kind = 'studio' or (m.id is not null and m.status = 'active'));
$$;

revoke all on function public.resolve_tag_fallback(text) from public, anon, authenticated, service_role;
grant execute on function public.resolve_tag_fallback(text) to anon;
grant execute on function public.resolve_tag_fallback(text) to authenticated;
