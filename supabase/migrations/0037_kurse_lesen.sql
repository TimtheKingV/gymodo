-- Die Lesepfade der Kurse, Spec 2026-09-03-kurse-design.md Abschnitt 5.
--
-- member/Kurse.dc.html zeigt einem Mitglied "12 von 16". Aber
-- course_bookings_select (0035) laesst ein Mitglied ausschliesslich
-- eigene Buchungen sehen -- es kann nicht zaehlen, was es nicht sieht.
--
-- Dieselbe Lage hatte 0034 beim Ueberblick, und dieselbe Antwort: eine
-- Aggregatfunktion liefert, was die Zeilen verwehren. Heraus kommen
-- ausschliesslich Zahlen und die EIGENE Buchung des Aufrufers, niemals
-- eine fremde Buchungszeile.

create or replace function public.course_week(
  p_studio_id uuid,
  p_from      timestamptz,
  p_to        timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
stable
as $$
declare
  v_zeitzone text;
  v_termine  jsonb;
begin
  if not public.is_studio_member(p_studio_id) then
    return null;
  end if;

  select timezone into v_zeitzone
    from public.studios
   where id = p_studio_id;

  select coalesce(jsonb_agg(x order by x.starts_at, x.name), '[]'::jsonb)
    into v_termine
    from (
      select
        s.id                 as session_id,
        s.course_template_id as template_id,
        c.name,
        c.description,
        s.starts_at,
        -- Der Tagesschluessel wird HIER gerechnet und mitgeliefert. Die
        -- Oberflaeche gruppiert danach und leitet ihn nie selbst ab --
        -- taete sie es, gruppierte der Server nach seiner eigenen
        -- Zeitzone, und eine Sommerzeitumstellung schoebe einen
        -- 18:00-Kurs auf den Vortag. Bei Trainingssaetzen fiele das nie
        -- auf, bei Kursen sofort.
        (s.starts_at at time zone v_zeitzone)::date as local_day,
        s.duration_min,
        s.capacity,
        s.room,
        -- Kein coalesce auf die Vorlage: die Werte werden beim Anlegen
        -- kopiert, nicht verwiesen (0035, Kommentar an capacity).
        s.instructor_name,
        s.status::text as status,
        (select count(*)::int
           from public.course_bookings b
          where b.course_session_id = s.id
            and b.status = 'booked')                     as booked_count,
        (select count(*)::int
           from public.course_bookings b
          where b.course_session_id = s.id
            and b.status = 'waitlisted')                 as waitlist_count,
        greatest(
          s.capacity - (select count(*)::int
                          from public.course_bookings b
                         where b.course_session_id = s.id
                           and b.status = 'booked'),
          0
        )                                                as free_seats,
        eb.status::text as own_status,
        eb.id           as own_booking_id,
        case when eb.status = 'waitlisted' then
          (select 1 + count(*)::int
             from public.course_bookings w
            where w.course_session_id = s.id
              and w.status = 'waitlisted'
              and (w.booked_at, w.id) < (eb.booked_at, eb.id))
        end as own_waitlist_position
      from public.course_sessions s
      join public.course_templates c on c.id = s.course_template_id
      left join public.course_bookings eb
        on eb.course_session_id = s.id
       and eb.user_id = auth.uid()
       and eb.status <> 'cancelled'
     where s.studio_id = p_studio_id
       and s.starts_at >= p_from
       and s.starts_at <  p_to
    ) x;

  return jsonb_build_object(
    'from',     p_from,
    'to',       p_to,
    'timezone', v_zeitzone,
    'sessions', v_termine
  );
end;
$$;

comment on function public.course_week(uuid, timestamptz, timestamptz) is
  'Der Wochenplan eines Studios, screenorientiert (M1-Spec 6.3): je Termin die Belegung als Zahl und die eigene Buchung des Aufrufers. Die einzige Stelle, an der ein Mitglied erfaehrt, wie voll ein Kurs ist -- course_bookings_select gibt ihm nur die eigene Zeile. Liefert nie eine fremde Buchungszeile. local_day ist der Tag in studios.timezone und wird hier gerechnet, damit die Oberflaeche nicht nach der Serverzeitzone gruppiert. Wer kein Mitglied ist, bekommt null; eine leere Woche ist eine leere Liste.';

revoke all on function public.course_week(uuid, timestamptz, timestamptz)
  from public, anon, authenticated, service_role;
grant execute on function public.course_week(uuid, timestamptz, timestamptz) to authenticated;

-- ---------------------------------------------------------------------
--
-- Die woertliche Entsprechung zu list_studio_members (0031): die Adresse
-- liegt in auth.users und damit ausserhalb der public-Policies, also
-- security definer mit is_studio_staff im Rumpf.
--
-- Termin.dc.html schreibt den Grund selbst unter die Liste: "Diese Liste
-- ist eine Anwesenheitsliste. Andere Mitglieder sehen sie nicht."

create or replace function public.list_course_participants(p_session_id uuid)
returns table (
  user_id           uuid,
  email             text,
  status            public.course_booking_status,
  booked_at         timestamptz,
  promoted_at       timestamptz,
  waitlist_position int
)
language plpgsql
security definer
set search_path = public, pg_temp
stable
as $$
declare
  v_studio uuid;
begin
  select s.studio_id into v_studio
    from public.course_sessions s
   where s.id = p_session_id;

  -- Leer, nicht Fehler -- wie list_studio_members. Ein Termin, den es
  -- nicht gibt, und einer aus einem fremden Studio antworten gleich.
  if v_studio is null or not public.is_studio_staff(v_studio) then
    return;
  end if;

  return query
    select b.user_id,
           u.email::text,
           b.status,
           b.booked_at,
           b.promoted_at,
           -- Gerechnet, nicht gespeichert (Spec Abschnitt 3). Die
           -- Partition ueber den Status nummeriert die Wartenden unter
           -- sich; fuer Gebuchte verwirft das case das Ergebnis.
           case when b.status = 'waitlisted' then
             (row_number() over (
                partition by b.status
                order by b.booked_at, b.id
             ))::int
           end
      from public.course_bookings b
      join auth.users u on u.id = b.user_id
     where b.course_session_id = p_session_id
       and b.status <> 'cancelled'
     order by b.status, b.booked_at, b.id;
end;
$$;

comment on function public.list_course_participants(uuid) is
  'Die Teilnehmerliste eines Kurstermins, nur fuer Personal. Die eine Stelle im Portal, an der Namen -- hier Adressen -- erscheinen; sie ist eine Anwesenheitsliste, sie gehoert dem Studio, und fuer andere Mitglieder ist sie unsichtbar (Portalspec Abschnitt 4). Stornierte Buchungen stehen nicht darauf, bleiben aber in der Tabelle. Wer kein Personal ist, bekommt die leere Menge, keinen Fehler.';

revoke all on function public.list_course_participants(uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.list_course_participants(uuid) to authenticated;
