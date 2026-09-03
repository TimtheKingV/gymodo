-- Die Platzvergabe, Spec 2026-09-03-kurse-design.md Abschnitt 2.
--
-- Ein Termin hat 16 Plaetze, 15 sind belegt, zwei Mitglieder tippen im
-- selben Augenblick auf "Anmelden". Zaehlen und dann schreiben hat ein
-- Fenster dazwischen: unter read committed -- der Vorgabe in Postgres --
-- sehen beide Transaktionen den Stand 15, beide schliessen auf einen
-- freien Platz, beide schreiben. Danach sind 17 Leute fuer 16 Plaetze
-- angemeldet, und niemand merkt es bis zum Kursbeginn.
--
-- Der Fehler ist nicht selten. Er tritt genau dann auf, wenn ein Kurs
-- beliebt ist -- also genau dann, wenn es darauf ankommt.
--
-- Beide Funktionen fassen deshalb als ERSTES dieselbe Zeile in
-- course_sessions mit for update an. Der Rumpf einer plpgsql-Funktion ist
-- eine Transaktion: die Sperre wird gefasst, gezaehlt, geschrieben und
-- freigegeben, ohne dass dazwischen ein Client antwortet. Es gibt kein
-- Netz im kritischen Abschnitt.
--
-- Dass Stornieren dieselbe Sperre nimmt, ist der Teil, den man beim
-- ersten Entwurf uebersieht -- aber NICHT aus dem Grund, den der erste
-- Entwurf dieses Kommentars hier nannte. Eine Stornierung und eine
-- Anmeldung koennen NICHT gleichzeitig zu dem Schluss kommen, es sei ein
-- Platz frei: Stornieren und Nachruecken laufen in cancel_course_booking
-- in DERSELBEN Transaktion, committen also zusammen. Der Zwischenzustand
-- "Platz frei, noch niemand nachgerueckt" wird nie fuer eine andere
-- Transaktion sichtbar -- eine gleichzeitige Anmeldung sieht entweder den
-- Zustand davor (Platz noch belegt) oder den vollstaendigen Zustand
-- danach (Platz frei UND bereits neu vergeben), und beides ist korrekt.
--
-- Die Sperre schuetzt gegen etwas anderes: ZWEI GLEICHZEITIGE
-- STORNIERUNGEN auf demselben Termin. Ohne sie storniert jede ihre
-- eigene Buchung unabhaengig, zaehlt unabhaengig und waehlt unabhaengig
-- "die erste Wartende" -- keine sieht die Nachrueckentscheidung der
-- anderen, weil beide vor jedem Commit laufen. Beide Unterabfragen loesen
-- auf dieselbe Person auf; die zweite Zuweisung blockiert kurz an der
-- Zeilensperre der ersten und schreibt danach dieselbe Zeile erneut.
-- Die Folge ist deshalb kein doppelt vergebener Platz, sondern eine
-- Unterbelegung: eine Person rutscht zweimal nach, eine andere Wartende
-- bleibt stehen, obwohl ein Platz frei wurde -- kleiner als zunaechst
-- gedacht, aber real, und fuer die zurueckbleibende Person nicht nichts.
--
-- Gefunden wurde das durch die Gegenprobe, nicht durch Lesen des Codes:
-- der erste Entwurf dieses Kommentars nannte den falschen Anlass, und der
-- Test, der aus diesem Anlass gebaut wurde, blieb auch ohne die Sperre
-- gruen.
--
-- Die Regel fuer beide Rueckgaben (Spec Abschnitt 5):
--   nicht erlaubt oder gibt es nicht → null
--   erlaubt, aber die Regel sagt nein → ein Ergebnis mit Grund
--
-- Die erste Haelfte ist die Orakel-Vermeidung aus 0030 und 0034. Die
-- zweite ist neu: "zu spaet zum Abmelden" ist kein Fehler, sondern ein
-- erwartetes Ergebnis -- der Mensch hat alles richtig gemacht, die Frist
-- ist eben abgelaufen. Als Exception muesste die Fachschicht einen
-- Postgres-Fehlertext abtasten, um daraus einen deutschen Satz zu machen.

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
  'Meldet den Aufrufer zu einem Kurstermin an. Sperrt die Terminzeile mit for update, zaehlt unter der Sperre und schreibt booked oder waitlisted. result ist IMMER der Zustand der Buchung, nie der Ausgang des Aufrufs; ob dieser Aufruf sie angelegt hat, sagt created. Damit muss der Aufrufer den Wiederholungsfall nicht unterscheiden, um zu wissen, woran er ist. Wer nicht Mitglied ist -- und ein Termin, den es nicht gibt -- bekommt null, keinen Fehler.';

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
  if v_buchung.status = 'booked'
     and v_ziel = v_user
     and v_session.status = 'planned' then
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

  return jsonb_build_object(
    'result',              'cancelled',
    'promoted_user_id',    v_nachr.user_id,
    'promoted_booking_id', v_nachr.id
  );
end;
$$;

comment on function public.cancel_course_booking(uuid, uuid) is
  'Meldet den Aufrufer ab -- oder, mit p_user_id und Staff-Rolle, jemand anderen. Nimmt dieselbe Zeilensperre wie book_course_session; Stornieren und Nachruecken passieren im selben gesperrten Abschnitt gegen ZWEI GLEICHZEITIGE Stornierungen -- ohne die Sperre waehlen beide unabhaengig dieselbe wartende Person, eine wird doppelt nachgerueckt, eine andere bleibt trotz freiem Platz stehen (nicht gegen Stornierung-gegen-Anmeldung: das committet atomar und kann nicht kollidieren). Die Stornofrist aus studios.cancellation_deadline_hours (0032) trifft nur das Mitglied selbst, nur einen bestaetigten Platz und nur einen Termin, der stattfindet. Wer nicht Mitglied ist oder ein fremdes Mitglied abmelden will, bekommt null.';

revoke all on function public.cancel_course_booking(uuid, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.cancel_course_booking(uuid, uuid) to authenticated;
