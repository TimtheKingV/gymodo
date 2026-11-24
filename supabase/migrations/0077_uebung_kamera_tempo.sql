-- Kameraprofil und Tempo an der Uebung (docs/superpowers/plans/2026-11-24-kamera-tempo-kern-katalog.md, Task 8).
--
-- Die Kamera erkennt Wiederholungen am Skelett. Dafuer braucht jede Uebung ein
-- Kameraprofil (wie das Mitglied das Handy aufstellt, welche Pflichtgelenke
-- sichtbar sein muessen), das Signal, an dem gezaehlt wird (Gelenk und Seite),
-- und das Uebungstempo (senken, halten, heben in Sekunden, plus die Phase, mit
-- der die Wiederholung beginnt).
--
-- 'ohne_kamera' heisst: die Uebung hat ein Tempo, wird aber nicht per Kamera
-- gezaehlt; dann gibt es weder Signal noch Seite. Alle Spalten sind null, solange
-- der Katalog kein Profil einer Uebung freigibt; es gibt keinen Backfill.
-- Ein Profil gibt es nur fuer Uebungen mit Wiederholungen (volume_kind 'reps').
-- Keine neue Policy: die Spalten erben die Zugriffe von exercises.

alter table public.exercises
  add column kamera_profil text,
  add column kamera_signal text,
  add column kamera_seite text,
  add column tempo_senken_s numeric(3, 1),
  add column tempo_halten_s numeric(3, 1),
  add column tempo_heben_s numeric(3, 1),
  add column tempo_beginnt_mit text;

alter table public.exercises
  add constraint exercises_kamera_profil_wert
    check (kamera_profil is null or kamera_profil in
      ('ganzkoerper_stehend', 'oberkoerper', 'stuetz_boden', 'liegend', 'zug_haengend', 'ohne_kamera')),
  add constraint exercises_kamera_signal_wert
    check (kamera_signal is null or kamera_signal in ('ellbogen', 'schulter', 'huefte', 'knie')),
  add constraint exercises_kamera_seite_wert
    check (kamera_seite is null or kamera_seite in ('links', 'rechts', 'beide')),
  -- Signal und Seite genau dann, wenn ein Profil gesetzt und nicht ohne_kamera ist.
  add constraint exercises_kamera_signal_seite_mit_profil
    check (
      (kamera_profil is not null and kamera_profil <> 'ohne_kamera') = (kamera_signal is not null)
      and (kamera_profil is not null and kamera_profil <> 'ohne_kamera') = (kamera_seite is not null)
    ),
  add constraint exercises_kamera_nur_bei_wiederholungen
    check (kamera_profil is null or volume_kind = 'reps'),
  add constraint exercises_tempo_beginnt_mit_wert
    check (tempo_beginnt_mit is null or tempo_beginnt_mit in ('senken', 'heben')),
  -- Die Startphase steht genau dann, wenn ein Profil gesetzt ist.
  add constraint exercises_tempo_beginnt_mit_mit_profil
    check ((tempo_beginnt_mit is not null) = (kamera_profil is not null)),
  -- Die drei Tempowerte: alle oder keiner, und nur mit Profil.
  add constraint exercises_tempo_vollstaendig
    check (
      (tempo_senken_s is not null) = (tempo_halten_s is not null)
      and (tempo_halten_s is not null) = (tempo_heben_s is not null)
    ),
  add constraint exercises_tempo_nur_mit_profil
    check (tempo_senken_s is null or kamera_profil is not null),
  -- Senken und heben 1,0 bis 4,0 s, halten 0,0 bis 3,0 s, alle im Raster 0,5 s.
  add constraint exercises_tempo_werte_raster
    check (
      (tempo_senken_s is null or (tempo_senken_s between 1.0 and 4.0 and tempo_senken_s * 2 = trunc(tempo_senken_s * 2)))
      and (tempo_halten_s is null or (tempo_halten_s between 0.0 and 3.0 and tempo_halten_s * 2 = trunc(tempo_halten_s * 2)))
      and (tempo_heben_s is null or (tempo_heben_s between 1.0 and 4.0 and tempo_heben_s * 2 = trunc(tempo_heben_s * 2)))
    );
