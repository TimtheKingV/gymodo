-- Testnotiz 14.10., 18:45 #3/#4: Training fortsetzen.
--
-- Die Luecke zwischen Beenden und Fortsetzen zaehlt als Pause, und Home
-- soll sie nicht als Trainingszeit zeigen. Der Server kannte bisher keine
-- Pause: die Dauer war Start bis Ende. paused_seconds ist die Summe aller
-- Pausen der Einheit, gesetzt vom Client beim Abschluss. Alte Einheiten
-- haben 0 und zeigen damit dieselbe Dauer wie bisher. Kein eigener Grant:
-- workout_sessions hat keine Spaltenrechte, die Update-Policy (0047) deckt
-- die Spalte mit.
alter table public.workout_sessions
  add column paused_seconds integer not null default 0
    constraint workout_sessions_paused_seconds_nicht_negativ
    check (paused_seconds >= 0);
