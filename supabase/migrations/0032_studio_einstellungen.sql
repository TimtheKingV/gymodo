-- Studio-Einstellungen, Spec 2026-08-31-trainerportal-struktur-design.md
-- Abschnitt 7: `studios` trug bis hier nur studios_select aus 0001. Es gab
-- keine Spalte fuer die Stornofrist und keinen Weg, Name oder Zeitzone zu
-- aendern -- die Einstellungsseite haette nichts zu speichern gehabt.

alter table public.studios
  add column cancellation_deadline_hours int not null default 2
    constraint studios_cancellation_deadline_range
      check (cancellation_deadline_hours between 0 and 168);

comment on column public.studios.cancellation_deadline_hours is
  'Stornofrist in Stunden vor Kursbeginn. Eine Studioregel, keine Plattformregel (Spec Abschnitt 8) -- deshalb steht sie am Studio und nicht in der Anwendung. 0 heisst "bis zum Beginn". Die Obergrenze von 168 Stunden ist eine Woche: was darueber steht, ist ein Tippfehler, keine Regel. Die Vorgabe von 2 Stunden stammt aus dem Artboard EinstellungenStudio; sie gilt auch fuer bereits bestehende Studios, weil ADD COLUMN mit DEFAULT jede Zeile fuellt -- ein NULL muesste die Oberflaeche sonst deuten.';

-- Speichern darf Personal, wie ueberall im Katalog (0004 ff.). Die
-- Bedingung steht auf beiden Seiten: ohne with check koennte ein Trainer
-- eine Zeile aus seinem Studio heraus-aendern, wenn studios je eine
-- zweite Zugehoerigkeitsspalte bekaeme.
create policy studios_update_staff on public.studios
  for update to authenticated
  using (public.is_studio_staff(id))
  with check (public.is_studio_staff(id));

-- Der Beitrittscode bleibt aussen vor -- und zwar ueber das Spaltenrecht,
-- nicht ueber die Policy.
--
-- 0030 haelt fest: "Nur regenerate_studio_join_code und
-- set_studio_join_code_active duerfen ihn aendern." Eine Policy kann das
-- nicht ausdruecken: with check sieht die neue Zeile, nie die alte, und
-- kann deshalb nicht verlangen, dass eine Spalte unveraendert bleibt. Ein
-- Grant kann es -- ohne UPDATE-Recht auf join_code prallt der Versuch
-- schon vor der Policy ab, mit 42501 statt einer leeren Treffermenge.
--
-- Was ohne diese Grenze offenstuende: studios_join_code_unique gilt ueber
-- alle Studios hinweg. Ein Trainer koennte einen fremden Code raten und
-- besetzen -- der Eigentuemer bekaeme beim naechsten Erneuern eine
-- unique_violation, und nach fuenf Versuchen bricht
-- regenerate_studio_join_code ab.
--
-- service_role bleibt unberuehrt (Onboarding legt Studios an), und die
-- SECURITY DEFINER-Funktionen aus 0030 laufen als Funktionsbesitzer, nicht
-- als Aufrufer -- dieser Entzug erreicht sie nicht.
revoke update on public.studios from authenticated;
grant update (name, timezone, cancellation_deadline_hours)
  on public.studios to authenticated;
