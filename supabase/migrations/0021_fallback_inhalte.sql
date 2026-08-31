-- Spec 6.4: der Web-Fallback ist keine Sackgasse, sondern sofort nuetzlich.
-- "So stellst du dieses Geraet ein", das Video laeuft, und erst darunter
-- steht der Installationshinweis. Aus einer Hinweisseite wird ein Trichter --
-- und es funktioniert auf Android, was die ehrliche Antwort auf die
-- Betreiberfrage nach Android-Mitgliedern ist.
--
-- Unveraendert bleibt: keine persoenlichen Daten, und identische Antwort fuer
-- unbekannt, ungueltig und gesperrt. Diese Funktion liefert deshalb in allen
-- drei Faellen null Zeilen und nie einen unterscheidbaren Fehler.

drop function if exists public.resolve_tag_fallback(text);

create function public.resolve_tag_fallback(p_token_hash text)
returns table (
  machine_tag_id uuid,
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
    t.id,
    m.label,
    em.name,
    em.photo_path,
    coalesce(
      (
        select jsonb_agg(
                 jsonb_build_object('name', e.name, 'video_path', video.storage_path)
                 order by eme.sort_order, e.name
               )
        from public.equipment_model_exercises eme
        join public.exercises e on e.id = eme.exercise_id
        -- Genau ein Video je Uebung, das neueste. 0018 macht nur (Uebung,
        -- Pfad) eindeutig -- zwei verschiedene Pfade waeren moeglich, und
        -- ohne feste Wahl zoege die Seite mal das eine, mal das andere.
        left join lateral (
          select ia.storage_path
          from public.instruction_assets ia
          where ia.equipment_model_exercise_id = eme.id
          order by ia.created_at desc, ia.id desc
          limit 1
        ) video on true
        where eme.equipment_model_id = em.id
      ),
      '[]'::jsonb
    )
  from public.machine_tags t
  join public.machines m on m.id = t.machine_id
  join public.equipment_models em on em.id = m.equipment_model_id
  where t.token_hash = p_token_hash
    and t.status = 'active'
    -- Ein stillgelegtes Geraet zeigt keine Einweisung mehr. Wer davorsteht,
    -- soll nicht lernen, wie man es einstellt.
    and m.status = 'active';
$$;

revoke all on function public.resolve_tag_fallback(text) from public;
grant execute on function public.resolve_tag_fallback(text) to anon;
grant execute on function public.resolve_tag_fallback(text) to authenticated;

-- Der Fallback braucht die Medien, ohne dass jemand angemeldet ist -- genau
-- das ist sein Sinn (Spec 6.4). Die Buckets bleiben trotzdem privat und die
-- URLs kurzlebig (Spec 6.8): freigegeben ist nicht "alles", sondern genau
-- das, worauf gerade ein aktiver Tag an einem Geraet in Betrieb zeigt.
--
-- Der Unterschied zaehlt: wird der Tag gesperrt oder das Geraet stillgelegt,
-- ist auch das Video im selben Moment anonym nicht mehr lesbar. Ein
-- oeffentlicher Bucket koennte das nicht zuruecknehmen.
create or replace function public.is_media_published(p_name text)
returns boolean
language sql
security definer
set search_path = public, pg_temp
stable
as $$
  select exists (
    select 1
    from public.machine_tags t
    join public.machines m on m.id = t.machine_id and m.status = 'active'
    join public.equipment_models em on em.id = m.equipment_model_id
    where t.status = 'active'
      and em.photo_path = p_name
  ) or exists (
    select 1
    from public.instruction_assets ia
    join public.equipment_model_exercises eme
      on eme.id = ia.equipment_model_exercise_id
    join public.equipment_models em on em.id = eme.equipment_model_id
    join public.machines m
      on m.equipment_model_id = em.id and m.status = 'active'
    join public.machine_tags t on t.machine_id = m.id and t.status = 'active'
    where ia.storage_path = p_name
  );
$$;

revoke all on function public.is_media_published(text) from public;
grant execute on function public.is_media_published(text) to anon;
grant execute on function public.is_media_published(text) to authenticated;

-- Die Policy laeuft bei jedem anonymen Objektzugriff, also brauchen beide
-- Pfadspalten einen Index. Der Unique-Index aus 0018 hilft nicht: dort steht
-- storage_path an zweiter Stelle.
create index if not exists equipment_models_photo_path_idx
  on public.equipment_models (photo_path);
create index if not exists instruction_assets_storage_path_idx
  on public.instruction_assets (storage_path);

-- Nur lesen, nur anon, nur veroeffentlicht. Schreiben und Loeschen bleiben
-- den Policies aus 0020 vorbehalten, die eine Mitgliedschaft verlangen.
create policy media_select_published on storage.objects
  for select to anon
  using (
    bucket_id in ('equipment-photos', 'instruction-videos')
    and public.is_media_published(name)
  );
