-- Ein studioloser Tag ist per RLS fuer jedes authenticated-Konto unsichtbar.
-- Der Sucher des Trainers saehe bei "frischer Tag aus eurer Lieferung" und bei
-- "fremder QR-Code" deshalb dasselbe: nichts. Das sind aber Zeile 1 und Zeile 5
-- der Antworttabelle -- die eine fuehrt zu Verbinden, die andere zu "melde dich
-- beim Betreiber". Ohne Lesefunktion ist die Tabelle nicht baubar.
--
-- Spec: docs/superpowers/specs/2026-09-01-tag-lieferung-design.md, Abschnitt 3.
-- Antworttabelle: 2026-09-01-einrichtung-am-geraet-design.md, Abschnitt 4.

create function public.inspect_tag(p_token text, p_studio_id uuid)
returns table (
  verdict       text,
  batch_code    text,
  batch_index   integer,
  machine_id    uuid,
  machine_label text
)
language plpgsql
security definer
set search_path = public, pg_temp
stable
as $$
declare
  t record;
begin
  -- Kein unauthorized, kein Fehler: wer nicht zum Studio gehoert, bekommt
  -- dieselbe Antwort wie auf einen Token, den es nicht gibt.
  if not public.is_studio_staff(p_studio_id) then
    return query select 'unbekannt'::text, null::text, null::integer, null::uuid, null::text;
    return;
  end if;

  select mt.id, mt.kind, mt.status, mt.studio_id, mt.machine_id, mt.batch_index,
         b.code as batch_code, b.scrapped_at, m.label as machine_label
    into t
    from public.machine_tags mt
    join public.tag_batches   b on b.id = mt.batch_id
    left join public.machines m on m.id = mt.machine_id
   where mt.token = p_token;

  -- Die Studiozugehoerigkeit wird ZUERST geprueft, und das ist keine
  -- Geschmackssache: ein gesperrter Tag eines fremden Studios muss unbekannt
  -- heissen, nicht gesperrt. Sonst verraet die Antwort seine Existenz.
  if not found
     or (t.studio_id is not null and t.studio_id <> p_studio_id) then
    return query select 'unbekannt'::text, null::text, null::integer, null::uuid, null::text;
    return;
  end if;

  if t.kind = 'studio' then
    if t.studio_id = p_studio_id and t.status = 'active' then
      -- Sackgasse mit genau einem Ausgang: das Schild ist bereits gueltig und
      -- gehoert an die Wand. Nichts zu verbinden, nichts freizuschalten.
      return query select 'aushangschild'::text, t.batch_code, t.batch_index, null::uuid, null::text;
    elsif t.studio_id = p_studio_id then
      return query select 'gesperrt'::text, t.batch_code, t.batch_index, null::uuid, null::text;
    else
      -- Ein studioloses Schild ist ein Versandfehler und noch nicht gueltig.
      return query select 'unbekannt'::text, null::text, null::integer, null::uuid, null::text;
    end if;
    return;
  end if;

  -- ab hier: kind = 'machine'
  if t.scrapped_at is not null or t.status in ('revoked', 'replaced') then
    return query select 'gesperrt'::text, t.batch_code, t.batch_index, null::uuid, null::text;
    return;
  end if;

  if t.status = 'unassigned' and t.machine_id is null then
    return query select 'frei'::text, t.batch_code, t.batch_index, null::uuid, null::text;
    return;
  end if;

  if t.status = 'active' and t.machine_id is not null then
    return query select 'vergeben'::text, t.batch_code, t.batch_index, t.machine_id, t.machine_label;
    return;
  end if;

  return query select 'unbekannt'::text, null::text, null::integer, null::uuid, null::text;
end
$$;

-- Das Studio kommt aus der MASCHINE, nicht aus einem Parameter. Waere es ein
-- Parameter, koennte der Aufrufer die Zuordnung selbst waehlen -- und die
-- Update-Policy aus 0016, die sonst dagegen stuende, greift fuer eine
-- studiolose Zeile nicht (is_studio_staff(null) ist false).
create function public.bind_tag_to_machine(p_token text, p_machine_id uuid)
returns table (verdict text, tag_id uuid)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_studio uuid;
  v_tag    record;
begin
  select m.studio_id into v_studio
    from public.machines m
   where m.id = p_machine_id
     and m.status = 'active';

  if v_studio is null or not public.is_studio_staff(v_studio) then
    return query select 'unbekannt'::text, null::uuid;
    return;
  end if;

  -- for update of mt sperrt nur die machine_tags-Zeile, nicht die Charge.
  -- Ohne sie waere das Rennen zweier Trainer an derselben Packung eine
  -- Constraint-Verletzung statt einer Antwort.
  select mt.id, mt.kind, mt.status, mt.studio_id, mt.machine_id, b.scrapped_at
    into v_tag
    from public.machine_tags mt
    join public.tag_batches  b on b.id = mt.batch_id
   where mt.token = p_token
     for update of mt;

  if not found
     or (v_tag.studio_id is not null and v_tag.studio_id <> v_studio) then
    return query select 'unbekannt'::text, null::uuid;
    return;
  end if;

  if v_tag.kind = 'studio' then
    if v_tag.studio_id = v_studio and v_tag.status = 'active' then
      return query select 'aushangschild'::text, null::uuid;
    elsif v_tag.studio_id = v_studio then
      return query select 'gesperrt'::text, null::uuid;
    else
      return query select 'unbekannt'::text, null::uuid;
    end if;
    return;
  end if;

  if v_tag.scrapped_at is not null or v_tag.status in ('revoked', 'replaced') then
    return query select 'gesperrt'::text, null::uuid;
    return;
  end if;

  if v_tag.machine_id is not null then
    return query select 'vergeben'::text, null::uuid;
    return;
  end if;

  update public.machine_tags
     set studio_id  = v_studio,
         machine_id = p_machine_id,
         status     = 'active'
   where id = v_tag.id;

  return query select 'gebunden'::text, v_tag.id;
end
$$;

-- revoke ... from public allein genuegt auf Supabase nicht: ALTER DEFAULT
-- PRIVILEGES gewaehrt EXECUTE zusaetzlich an anon, authenticated und
-- service_role. Ohne den ausdruecklichen Entzug waere jede dieser Funktionen
-- fuer alle drei aufrufbar. Die Lehre aus 0009.
revoke all on function public.inspect_tag(text, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.inspect_tag(text, uuid) to authenticated;

revoke all on function public.bind_tag_to_machine(text, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.bind_tag_to_machine(text, uuid) to authenticated;
