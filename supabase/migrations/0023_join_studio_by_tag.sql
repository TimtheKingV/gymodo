-- Der Beitritt liegt in einer Funktion, nicht in einer Insert-Policy: ein
-- Nicht-Mitglied darf machine_tags nicht lesen (machine_tags_select verlangt
-- is_studio_member), kann die Zuordnung also nicht selbst herstellen. Ein
-- Insert-Recht auf studio_memberships waere zudem breiter als noetig -- es
-- erlaubte, sich in ein beliebiges Studio einzutragen, statt nur in das,
-- dessen Tag man in der Hand haelt.
create or replace function public.join_studio_by_tag(p_token_hash text)
returns table (studio_id uuid, machine_id uuid, joined boolean)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user    uuid := auth.uid();
  v_studio  uuid;
  v_machine uuid;
  v_neu     boolean;
begin
  if v_user is null then
    return;
  end if;

  -- Unbekannt, gesperrt und nicht zugewiesen antworten identisch: leer.
  -- Differenzierte Antworten machten die Funktion zum Orakel, mit dem sich
  -- gueltige Tokens durch Ausprobieren finden liessen.
  select t.studio_id, t.machine_id
    into v_studio, v_machine
    from public.machine_tags t
   where t.token_hash = p_token_hash
     and t.status = 'active';

  if v_studio is null then
    return;
  end if;

  -- do nothing, nicht do update: ein Trainer, der ein Geraet im eigenen
  -- Studio scannt, darf dabei nicht auf member zurueckfallen. Die Rolle
  -- steht fest im Rumpf und kommt nie von aussen -- ein Scan macht zum
  -- Mitglied, nie zum Trainer.
  insert into public.studio_memberships (studio_id, user_id, role)
  values (v_studio, v_user, 'member')
  on conflict on constraint studio_memberships_studio_id_user_id_key do nothing;

  v_neu := found;

  return query select v_studio as studio_id, v_machine as machine_id, v_neu as joined;
end;
$$;

-- revoke ... from public allein genuegt auf Supabase nicht (siehe 0009).
revoke all on function public.join_studio_by_tag(text)
  from public, anon, authenticated, service_role;
grant execute on function public.join_studio_by_tag(text) to authenticated;
