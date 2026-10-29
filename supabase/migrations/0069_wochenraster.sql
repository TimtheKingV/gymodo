-- Wochenraster im Trainingsprofil und im Plan (Spec Wochenplan-Tab).
--
-- Das Profil bekommt vier Spalten: feste Kurs- und Cardio-Tage, die Cardio-Arten
-- und die gewuenschten Krafttage (ISO-Wochentag 1 = Montag ... 7 = Sonntag).
-- Bestehende Zeilen bekommen leere Listen, das Verhalten bleibt wie vorher.
-- Die Fachschicht (pruefeWoche) prueft zuerst, die Checks sind das Netz darunter;
-- die Policies von training_profiles (0060) gelten unveraendert.
--
-- training_plans.wochenraster nimmt das berechnete Raster auf (schreibt der
-- Generator); es ist immer ein JSON-Array, leer fuer bestehende Plaene.

alter table public.training_profiles
  add column kurs_tage    smallint[] not null default '{}',
  add column cardio_tage  smallint[] not null default '{}',
  add column cardio_arten text[]     not null default '{}',
  add column kraft_tage   smallint[] not null default '{}',
  add constraint training_profiles_kurs_tage_werte   check (kurs_tage   <@ array[1,2,3,4,5,6,7]::smallint[]),
  add constraint training_profiles_cardio_tage_werte check (cardio_tage <@ array[1,2,3,4,5,6,7]::smallint[]),
  add constraint training_profiles_kraft_tage_werte  check (kraft_tage  <@ array[1,2,3,4,5,6,7]::smallint[]),
  add constraint training_profiles_cardio_arten_werte
    check (cardio_arten <@ array['laufen', 'radfahren', 'schwimmen', 'wandern', 'anderes']::text[]),
  -- Ein Tag gehoert hoechstens zu einer Art; && ist "haben gemeinsame Elemente".
  add constraint training_profiles_kurs_cardio_getrennt  check (not (kurs_tage   && cardio_tage)),
  add constraint training_profiles_kurs_kraft_getrennt   check (not (kurs_tage   && kraft_tage)),
  add constraint training_profiles_cardio_kraft_getrennt check (not (cardio_tage && kraft_tage));

alter table public.training_plans
  add column wochenraster jsonb not null default '[]' check (jsonb_typeof(wochenraster) = 'array');
