-- Der Token war bisher nur als SHA-256 gespeichert. Die eine Eigenschaft, die
-- das kaufte -- ein Datenbankabzug ist keine fertige Liste funktionierender
-- Adressen -- ist weniger wert als ihr Preis. Wer den Abzug hat, hat darin
-- ohnehin studios, machines, studio_memberships und ueber auth.users die
-- Mailadressen; die Tokenliste ist der harmloseste Posten darin. Bezahlt wurde
-- sie mit dem Druckbogen, danach mit der einmaligen Anzeige, und als naechstes
-- haette sie eine Klartextliste erzwungen, deren Verlust eine ganze Charge
-- verschrottet.
--
-- An ihre Stelle treten Spaltenrechte. Der Klartext steht in machine_tags.token,
-- aber authenticated darf ihn weder lesen noch schreiben. token_hash bleibt --
-- gleicher Name, gleiche Werte, gleiche Unique --, nur wird er jetzt abgeleitet
-- statt eingefuegt. Deshalb bleiben bootstrap.ts, tag-context.ts,
-- resolve_tag_fallback und join_studio_by_tag woertlich unveraendert.
--
-- Spec: docs/superpowers/specs/2026-09-01-tag-lieferung-design.md, Abschnitt 1.

-- Der Klartext bestehender Zeilen ist per Definition unwiederbringlich -- genau
-- die Eigenschaft, die diese Migration abschafft. Er kann nicht nachgetragen
-- werden, die Zeilen muessen weg. Bestand ist ausschliesslich synthetisch
-- (2026-08-28-fitness-retrofit-m1-design.md, Abschnitt 9), und kein Tag ist je
-- physisch gedruckt worden.
delete from public.machine_tags;

alter table public.machine_tags drop constraint machine_tags_token_hash_key;
alter table public.machine_tags drop column token_hash;

-- decode(token, 'escape') statt convert_to(token, 'UTF8'): convert_to ist
-- STABLE und in einer generierten Spalte nicht zulaessig, decode ist IMMUTABLE.
-- Das Tokenformat laesst ohnehin nur ASCII zu, also sind beide byteweise gleich.
alter table public.machine_tags
  add column token text not null
    check (token ~ '^[A-Za-z0-9_-]{22}$'),
  add column token_hash text
    generated always as (encode(sha256(decode(token, 'escape')), 'hex')) stored;

alter table public.machine_tags
  add constraint machine_tags_token_key      unique (token),
  add constraint machine_tags_token_hash_key unique (token_hash);

-- Der eigentliche Zweck. Ohne den Entzug von select liest jedes Mitglied ueber
-- machine_tags_select den Token des Aushangschilds seines Studios und kann die
-- Beitritts-URL streuen, ohne das Schild zu fotografieren. Ohne den Entzug von
-- update koennte ein Trainer einem Schild seines Studios einen selbst
-- gewaehlten Token geben und dasselbe tun.
revoke select, insert, update on public.machine_tags from authenticated, anon;

grant select (id, studio_id, machine_id, token_hash, status, kind,
              created_at, revoked_at)
  on public.machine_tags to authenticated;

grant update (machine_id, status, revoked_at)
  on public.machine_tags to authenticated;

-- Kein grant insert. token ist not null und wird nicht gewaehrt, also scheitert
-- jedes Insert eines Trainers ohnehin -- welche Spalten er auch nennt. Ein
-- Insert-Recht waere ein Versprechen ohne Deckung.
--
-- Damit faellt auch die Policy aus 0016. Ihre Begruendung dort -- "der Grund,
-- warum ein Studio sich nicht ohne Entwicklerhilfe einrichten liess" -- ist
-- durch die Lieferung abgeloest: Tag-Zeilen entstehen beim Betreiber. Wer sie
-- stehen liesse, hinterliesse eine Policy, die einen Weg beschreibt, den es
-- nicht gibt.
drop policy machine_tags_insert on public.machine_tags;
