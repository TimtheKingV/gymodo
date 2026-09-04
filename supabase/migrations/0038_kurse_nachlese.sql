-- Nachlese aus dem Gesamt-Review von Phase 4, Kurse.
--
-- Vier Befunde wurden erst sichtbar, als alle Teile zusammenstanden --
-- keiner ist in 0035 bis 0037 einzeln aufgefallen. Diese Migration
-- traegt die, die die Datenbank betreffen:
--
--  1. cancel_course_booking gab die Identitaet der nachgerueckten Person
--     an JEDEN Aufrufer zurueck -- auch an ein einfaches Mitglied, das
--     die eigene Buchung storniert. course_bookings_select (0035) ist
--     genau dafuer da, das zu verhindern, und die SECURITY-DEFINER-
--     Funktion hat sie umgangen. Jetzt gilt: Personal bekommt
--     promoted_user_id und promoted_booking_id, jeder andere Aufrufer
--     nur noch ein Ja/Nein in promoted.
--
--  2. capacity ist ueber course_sessions_update_staff direkt von
--     Personal schreibbar -- ausserhalb der beiden gesperrten
--     Funktionen. Nachruecken passiert sonst NUR in
--     cancel_course_booking; eine Kapazitaetserhoehung bei wartender
--     Liste liesse also nie jemanden nachruecken, und course_week
--     zeigte free_seats und waitlist_count gleichzeitig auf demselben
--     Termin. promote_course_waitlist schliesst diese zweite Luecke.
--
--  3. Ein wiederverwendetes p_booking_id nach einer Stornierung fuehrte
--     in eine Primary-Key-Verletzung (23505) statt in eine saubere
--     Antwort: der Teilindex course_bookings_one_per_member schliesst
--     stornierte Zeilen aus, die Kennung an der Primary Key aber nicht.
--     book_course_session erkennt den Fall jetzt vor dem Insert.
--
--  4. Wer waehrend der Stornofrist nachgerueckt ist, konnte den Platz
--     nie wieder loswerden: die Frist griff auch fuer einen Platz, den
--     das Mitglied nie freiwillig angenommen hat. Die Frist gilt jetzt
--     nicht mehr fuer eine nachgerueckte Buchung.

create or replace function public.book_course_session(
  p_session_id uuid,
  p_booking_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user     uuid := auth.uid();
  v_session  public.course_sessions;
  v_buchung  public.course_bookings;
  v_created  boolean := false;
  v_belegt   int;
  v_status   public.course_booking_status;
  v_position int;
begin
  if v_user is null or p_booking_id is null then
    return null;
  end if;

  -- Die Sperre. Alles Weitere laeuft unter ihr.
  select * into v_session
    from public.course_sessions
   where id = p_session_id
   for update;

  -- Ein fremder und ein nicht existierender Termin antworten identisch.
  if not found or not public.is_studio_member(v_session.studio_id) then
    return null;
  end if;

  if v_session.status = 'cancelled' then
    return jsonb_build_object('result', 'session_cancelled', 'created', false);
  end if;

  -- Die Grenze ist der Beginn, nicht das Ende: ein Kurs, der um 18:00
  -- anfaengt, nimmt um 18:20 niemanden mehr auf.
  if v_session.starts_at <= now() then
    return jsonb_build_object('result', 'past', 'created', false);
  end if;

  select * into v_buchung
    from public.course_bookings
   where course_session_id = p_session_id
     and user_id = v_user
     and status <> 'cancelled';

  if not found then
    -- Derselbe Client cached p_booking_id je Termin, damit derselbe PUT
    -- zweimal denselben Platz ergibt (0035, Kommentar an id). Storniert
    -- das Mitglied und bucht mit DERSELBEN Kennung erneut, schliesst der
    -- Teilindex die stornierte Zeile aus -- der obige Select findet
    -- nichts -- aber die Primary Key haelt die Kennung noch. Ohne diese
    -- Pruefung liefe der Insert unten in 23505. Erlaubt ist die
    -- Wiederverwendung trotzdem nicht: eine neue, freie Kennung ist
    -- Sache des Clients.
    if exists (
      select 1 from public.course_bookings where id = p_booking_id
    ) then
      return jsonb_build_object('result', 'booking_id_reused', 'created', false);
    end if;

    select count(*) into v_belegt
      from public.course_bookings
     where course_session_id = p_session_id
       and status = 'booked';

    if v_belegt < v_session.capacity then
      v_status := 'booked';
    else
      v_status := 'waitlisted';
    end if;

    insert into public.course_bookings
      (id, studio_id, course_session_id, user_id, status)
    values
      (p_booking_id, v_session.studio_id, p_session_id, v_user, v_status)
    returning * into v_buchung;

    v_created := true;
  end if;

  -- Die Position wird gerechnet, nicht gespeichert (Spec Abschnitt 3).
  -- Der Zeilenvergleich (booked_at, id) < (…) ist row_number() ueber
  -- dieselbe Ordnung, nur ohne Fenster.
  if v_buchung.status = 'waitlisted' then
    select 1 + count(*) into v_position
      from public.course_bookings
     where course_session_id = p_session_id
       and status = 'waitlisted'
       and (booked_at, id) < (v_buchung.booked_at, v_buchung.id);
  else
    v_position := null;
  end if;

  -- greatest(…, 0): bei einer nachtraeglich verkleinerten Kapazitaet
  -- stuenden sonst negative freie Plaetze auf dem Bildschirm.
  select greatest(v_session.capacity - count(*), 0) into v_belegt
    from public.course_bookings
   where course_session_id = p_session_id
     and status = 'booked';

  return jsonb_build_object(
    'result',            v_buchung.status,
    'created',           v_created,
    'booking_id',        v_buchung.id,
    'waitlist_position', v_position,
    'free_seats',        v_belegt
  );
end;
$$;

comment on function public.book_course_session(uuid, uuid) is
  'Meldet den Aufrufer zu einem Kurstermin an. Sperrt die Terminzeile mit for update, zaehlt unter der Sperre und schreibt booked oder waitlisted. result ist IMMER der Zustand der Buchung, nie der Ausgang des Aufrufs; ob dieser Aufruf sie angelegt hat, sagt created. booking_id_reused: p_booking_id gehoert bereits zu einer anderen Zeile (oft der eigenen, laengst stornierten) -- der Client muss eine frische Kennung erzeugen. Wer nicht Mitglied ist -- und ein Termin, den es nicht gibt -- bekommt null, keinen Fehler.';

revoke all on function public.book_course_session(uuid, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.book_course_session(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------

create or replace function public.cancel_course_booking(
  p_session_id uuid,
  p_user_id    uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user    uuid := auth.uid();
  v_ziel    uuid;
  v_session public.course_sessions;
  v_buchung public.course_bookings;
  v_frist   int;
  v_nachr   public.course_bookings;
begin
  if v_user is null then
    return null;
  end if;

  -- null heisst "ich selbst". Personal uebergibt eine Kennung, um
  -- jemanden zu entfernen -- Termin.dc.html hat neben jedem Teilnehmer
  -- ein "Abmelden". Eine Signatur fuer beide Aufrufer, eine Sperre.
  v_ziel := coalesce(p_user_id, v_user);

  -- DIESELBE Sperre wie book_course_session. Siehe Kopf.
  select * into v_session
    from public.course_sessions
   where id = p_session_id
   for update;

  if not found or not public.is_studio_member(v_session.studio_id) then
    return null;
  end if;

  if v_ziel <> v_user and not public.is_studio_staff(v_session.studio_id) then
    return null;
  end if;

  select * into v_buchung
    from public.course_bookings
   where course_session_id = p_session_id
     and user_id = v_ziel
     and status <> 'cancelled';

  if not found then
    return jsonb_build_object('result', 'not_booked');
  end if;

  -- Die Frist trifft nur das Mitglied, nur einen bestaetigten Platz und
  -- nur einen Termin, der stattfindet:
  --
  --  * Von der WARTELISTE zu gehen kostet niemanden einen Platz -- dafuer
  --    eine Frist zu verlangen waere eine Regel ohne Zweck.
  --  * PERSONAL, das seinen eigenen Kurs verwaltet, kann nicht von einer
  --    Mitgliederfrist ausgesperrt werden; es entfernt jemanden, weil es
  --    einen Grund dazu hat, nicht weil eine Frist es erlaubt.
  --  * Bei einem ABGESAGTEN Termin schuetzt die Frist nichts mehr. Sie
  --    besteht, damit das Studio einen frei werdenden Platz nachbesetzen
  --    kann; faellt der Kurs aus, gibt es nichts nachzubesetzen.
  --  * Und (neu, 0038): eine NACHGERUECKTE Buchung ist ausgenommen. Die
  --    Frist existiert, damit das Studio einen Platz nachbesetzen kann,
  --    den jemand FREIWILLIG aufgibt. Ein Platz, der jemandem ungefragt
  --    zugeteilt wurde -- innerhalb der Frist, weil das automatische
  --    Nachruecken keine Uhr kennt --, war nie freiwillig angenommen.
  --    Ohne diese Ausnahme saesse die betroffene Person in einer
  --    Anmeldung fest, aus der sie nie wieder herauskommt: das
  --    Nachruecken selbst erfolgt nur in einen Termin, der noch stattfindet,
  --    also immer VOR dessen Beginn, und die Frist begann fuer sie damit
  --    gleich mit.
  if v_buchung.status = 'booked'
     and v_ziel = v_user
     and v_session.status = 'planned'
     and v_buchung.promoted_at is null then
    select cancellation_deadline_hours into v_frist
      from public.studios
     where id = v_session.studio_id;

    if now() > v_session.starts_at - make_interval(hours => v_frist) then
      return jsonb_build_object(
        'result',         'deadline',
        'deadline_hours', v_frist,
        'starts_at',      v_session.starts_at
      );
    end if;
  end if;

  update public.course_bookings
     set status = 'cancelled', cancelled_at = now()
   where id = v_buchung.id;

  -- Nachruecken im selben gesperrten Abschnitt. Nicht in einen
  -- abgesagten und nicht in einen vergangenen Termin: jemanden in einen
  -- Kurs zu befoerdern, der ausfaellt, waere eine Zusage, die das Studio
  -- schon zurueckgenommen hat.
  --
  -- Und nicht, wenn kein Platz frei ist: eine nachtraeglich verkleinerte
  -- Kapazitaet (0035 erlaubt das; siehe greatest(…, 0) oben) kann einen
  -- Termin ueber sein eigenes Limit bringen -- zehn Buchungen, Kapazitaet
  -- auf fuenf gesenkt. Storniert dort jemand, ist die Zeile eben von
  -- oben stornierten Buchung bereits weg; die Zaehlung danach spiegelt
  -- den frei gewordenen Platz. Wuerde trotzdem nachgerueckt, bliebe der
  -- Termin fuer immer ueberbucht: jede weitere Stornierung wuerde die
  -- Ueberbuchung nur erneut auffuellen, statt sie abzubauen.
  if v_buchung.status = 'booked'
     and v_session.status = 'planned'
     and v_session.starts_at > now()
     and (select count(*)
            from public.course_bookings
           where course_session_id = p_session_id
             and status = 'booked') < v_session.capacity then
    update public.course_bookings
       set status = 'booked', promoted_at = clock_timestamp()
     where id = (
       select id
         from public.course_bookings
        where course_session_id = p_session_id
          and status = 'waitlisted'
        order by booked_at, id
        limit 1
     )
    returning * into v_nachr;
  end if;

  -- Wer nachgerueckt ist, erfaehrt nur Personal (0038): course_bookings_select
  -- (0035) verbietet einem Mitglied, die Buchungszeile einer anderen Person
  -- zu sehen -- diese SECURITY-DEFINER-Funktion darf diese Grenze nicht ueber
  -- den Rueckgabewert wieder aufmachen. Jeder Aufrufer erfaehrt trotzdem, DASS
  -- jemand nachgerueckt ist (promoted) -- nur nicht, WER.
  return jsonb_build_object(
    'result',   'cancelled',
    'promoted', v_nachr.id is not null
  ) || case
         when public.is_studio_staff(v_session.studio_id) then
           jsonb_build_object(
             'promoted_user_id',    v_nachr.user_id,
             'promoted_booking_id', v_nachr.id
           )
         else '{}'::jsonb
       end;
end;
$$;

comment on function public.cancel_course_booking(uuid, uuid) is
  'Meldet den Aufrufer ab -- oder, mit p_user_id und Staff-Rolle, jemand anderen. Nimmt dieselbe Zeilensperre wie book_course_session; Stornieren und Nachruecken passieren im selben gesperrten Abschnitt gegen ZWEI GLEICHZEITIGE Stornierungen -- ohne die Sperre waehlen beide unabhaengig dieselbe wartende Person, eine wird doppelt nachgerueckt, eine andere bleibt trotz freiem Platz stehen (nicht gegen Stornierung-gegen-Anmeldung: das committet atomar und kann nicht kollidieren). Die Stornofrist aus studios.cancellation_deadline_hours (0032) trifft nur das Mitglied selbst, nur einen bestaetigten und nicht nachgerueckten Platz, und nur einen Termin, der stattfindet. promoted_user_id und promoted_booking_id stehen nur in der Antwort an Personal (0038) -- ein Mitglied erfaehrt nur das Ja/Nein in promoted, nie die Identitaet. Wer nicht Mitglied ist oder ein fremdes Mitglied abmelden will, bekommt null.';

revoke all on function public.cancel_course_booking(uuid, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.cancel_course_booking(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------

create or replace function public.promote_course_waitlist(p_session_id uuid)
returns int
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_session public.course_sessions;
  v_belegt  int;
  v_frei    int;
  v_anzahl  int;
begin
  -- Dieselbe Sperre wie book_course_session und cancel_course_booking.
  select * into v_session
    from public.course_sessions
   where id = p_session_id
   for update;

  if not found or not public.is_studio_staff(v_session.studio_id) then
    return 0;
  end if;

  if v_session.status = 'cancelled' or v_session.starts_at <= now() then
    return 0;
  end if;

  select count(*) into v_belegt
    from public.course_bookings
   where course_session_id = p_session_id
     and status = 'booked';

  v_frei := v_session.capacity - v_belegt;
  if v_frei <= 0 then
    return 0;
  end if;

  -- Ein Satz statt einer Schleife -- unter derselben Zeilensperre ist
  -- das gleichwertig, weil kein anderer Schreiber auf diesen Termin
  -- dazwischenkommen kann: book_course_session und cancel_course_booking
  -- nehmen dieselbe Sperre, bevor sie irgendetwas lesen.
  with kandidaten as (
    select id
      from public.course_bookings
     where course_session_id = p_session_id
       and status = 'waitlisted'
     order by booked_at, id
     limit v_frei
  )
  update public.course_bookings b
     set status = 'booked', promoted_at = clock_timestamp()
    from kandidaten k
   where b.id = k.id;

  get diagnostics v_anzahl = row_count;
  return v_anzahl;
end;
$$;

comment on function public.promote_course_waitlist(uuid) is
  'capacity ist ueber course_sessions_update_staff direkt von Personal schreibbar -- ausserhalb der beiden gesperrten Funktionen book_course_session und cancel_course_booking. Nachruecken passiert sonst NUR innerhalb von cancel_course_booking; eine Kapazitaetserhoehung mit wartender Liste liesse also nie jemanden nachruecken, und course_week zeigte free_seats und waitlist_count gleichzeitig auf demselben Termin. Nimmt dieselbe Zeilensperre wie die beiden anderen Funktionen, bevor sie irgendetwas liest. Promoviert nichts in einen abgesagten oder vergangenen Termin. Wer nicht Personal des Studios ist, bekommt 0, keinen Fehler.';

revoke all on function public.promote_course_waitlist(uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.promote_course_waitlist(uuid) to authenticated;
