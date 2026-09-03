# Tags als Lieferung — Tokenraum, Chargen und das Betreiberwerkzeug

**Stand:** 1. September 2026
**Status:** Entwurf, abgestimmt. Noch keine Umsetzung.
**Vorgänger:** `2026-09-01-einrichtung-am-geraet-design.md` (Tags als Lieferung, der Gang durch die Halle), `2026-09-01-scan-beitritt-design.md` (Tokenraum, `kind`, Aushang), `2026-09-01-konflikte-scan-und-einrichtung.md` (die vier Entscheidungen)
**Ändert:** `2026-09-01-einrichtung-am-geraet-design.md` §1, §4, §5 und §6. Und die Global Constraints von `2026-09-01-scan-beitritt-datenbank.md` — der Satz *„Der Klartext-Token existiert genau einmal"* fällt.
**Belegt:** Migrationen `0026`, `0027`, `0028`, `0029`. Der Datenbankplan behält `0022`–`0025` unangetastet. `0029` kam erst waehrend der Umsetzung dazu (siehe Abschnitt 2, `0027_tag_chargen.sql` -- Nachgezogen, Migration `0029`) und ist kein Bruch dieser Zaehlung.
**Canvas:** keine Änderung. `Tags.dc.html` trägt *Lieferungen*, *Charge 8 · geliefert*, *vorrätig* und die einzeln gelisteten Schilder bereits.

---

## Warum dieses Dokument existiert

Der Konfliktbericht endet mit einem Satz, der eine Lücke benennt statt sie zu schließen:

> **Nicht in diesem Plan enthalten:** das Anlegen der Lieferzeilen. Das ist Betreiberarbeit und gehört in einen eigenen Plan.

Das ist die Lücke, die Entscheidung 1 aufgerissen hat. Seit ein Aushangschild **ab Lieferung** gültig ist und das Portal nie aktiviert, hängt die Funktionsfähigkeit eines Schilds an einer Handlung, für die es weder Bildschirm noch Code noch Skript gibt. Ohne sie ist die Kette vollständig entworfen und an genau einer Stelle unterbrochen: es entsteht keine einzige Tag-Zeile mehr.

Beim Entwerfen dieser Handlung kamen zwei Annahmen ans Licht, die beide Vorgängerspecs unbesehen weitergereicht haben.

**Die erste:** dass der Token gehasht gespeichert bleiben muss. Er muss es nicht, und der Hash war die Wurzel fast aller Umständlichkeit in diesem Bereich — er hat den Druckbogen erzwungen, danach die einmalige Anzeige, und hätte als nächstes eine Klartextliste erzwungen, deren Verlust eine Tausendercharge verschrottet.

**Die zweite:** dass der Betreiber beim Kommissionieren weiß, *welche* Aufkleber er in welche Kiste legt. Er weiß es nicht, und er muss es für Gerätetags auch nicht wissen.

---

## Entscheidungen

Fünf, alle in dieser Runde getroffen:

1. **Der Token steht im Klartext in der Datenbank** — aber `authenticated` darf ihn weder lesen noch schreiben. `token_hash` bleibt als *generierte* Spalte bestehen, unverändert lesbar.
2. **Die Halde liegt in der Datenbank, nicht daneben.** Ein Token existiert an genau einem Ort, von der Herstellung bis zur Sperrung, mit einer Zeilen-ID, die sich nie ändert.
3. **Gerätetags kommen studiolos.** Sie lernen ihr Studio beim Scan vor dem Gerät, nicht beim Versand. Der Betreiber erfasst beim Kommissionieren nichts.
4. **Aushangschilder werden namentlich zugeordnet.** Fünf Nummern pro Studio, eingetippt. Ein Schild ohne Studio ist sinnlos, und es gibt für es keinen Bindeschritt.
5. **Eine Lieferung ist eine Zahl.** Sie benennt keinen Token. Das folgt aus Entscheidung 3 der Einrichtungs-Spec (*„Der Vorrat ist eine Zahl, keine Liste"*): wenn der Vorrat eine Zahl sein darf, darf die Lieferung es auch.

---

## 1. Der Tokenraum wird lesbar

### Was der Hash gekauft hat, und was er kostete

Die Vorgängerspec begründet den Hash selbst, und die Begründung trägt genau eine Eigenschaft: *„verhindert, dass ein Datenbankabzug eine fertige Liste funktionierender Adressen aller Studios ist."* `packages/domain/src/tags.ts` sagt im selben Atemzug, der Token sei *„ein oeffentlicher Locator, keine Authentisierung."*

Wer einen Abzug hat, hat darin `studios`, `machines`, `studio_memberships`, `workout_sets` und über `auth.users` die Mailadressen. Die Tokenliste ist der harmloseste Posten des Abzugs. **Der Hash verteidigt gegen einen Angreifer, der bereits mehr hat, als die Tokens hergeben.**

Was er kostete, steht im Konfliktbericht: der Druckbogen, der nur im Augenblick des Anlegens entstehen konnte; die einmalige Anzeige; die Regel, dass jede Oberfläche mit „es gibt keinen zweiten Blick" rechnen muss. Und als nächstes hätte er eine Klartext-CSV erzwungen, die das Haus verlässt und nie wieder erzeugbar ist.

### Was er *nicht* gekauft hat

Der Token **ist** die URL `/t/<token>`. Ein Foto des Aushangschilds im Netz macht jeden Betrachter per `join_studio_by_tag` zum Mitglied — mit Hash genauso wie ohne. Dagegen hilft nur eine Ratenbegrenzung oder ein Ablauf; beides steht als offener Punkt in `2026-09-01-scan-beitritt-design.md` §7 und bleibt dort.

### Der eine echte Unterschied, und wie er geschlossen wird

`machine_tags_select` lässt jedes **Mitglied** alle Tag-Zeilen seines Studios lesen. Stünde der Token dort im Klartext, könnte ein Mitglied die Beitritts-URL des Aushangschilds auslesen und streuen, ohne das Schild zu fotografieren. Deshalb Spaltenrechte statt bloßem Klartext.

### `0026_tag_klartext.sql`

```sql
-- Der Klartext bestehender Zeilen ist per Definition unwiederbringlich -- genau
-- die Eigenschaft, die diese Migration abschafft. Sie koennen nicht nachgetragen
-- werden. Bestand ist ausschliesslich synthetisch (Spec 2026-08-28 §9).
delete from public.machine_tags;

alter table public.machine_tags drop constraint machine_tags_token_hash_key;
alter table public.machine_tags drop column token_hash;

alter table public.machine_tags
  add column token text not null
    check (token ~ '^[A-Za-z0-9_-]{22}$'),
  add column token_hash text
    generated always as (encode(sha256(decode(token, 'escape')), 'hex')) stored,
  add constraint machine_tags_token_key      unique (token),
  add constraint machine_tags_token_hash_key unique (token_hash);
```

`decode(token, 'escape')` statt `convert_to(token, 'UTF8')`: `convert_to` ist `STABLE` und in einer generierten Spalte nicht zulässig, `decode` ist `IMMUTABLE`. Für ASCII-Tokens sind beide byteweise gleich. Gegen PostgreSQL 17.6 geprüft — das Ergebnis stimmt mit `hashTagToken` aus Node exakt überein.

Dann die Rechte, der eigentliche Zweck:

```sql
revoke select, insert, update on public.machine_tags from authenticated, anon;

grant select (id, studio_id, machine_id, token_hash, status, kind,
              created_at, revoked_at)
  on public.machine_tags to authenticated;

grant update (machine_id, status, revoked_at)
  on public.machine_tags to authenticated;
```

**Die Spaltenliste ist eine Liste, keine Ausnahme** — sie zählt auf, was erlaubt ist, und weiß deshalb nichts von Spalten, die es noch nicht gibt. `0027` fügt `batch_id` und `batch_index` hinzu und **muss den `select`-Grant deshalb erneuern**; ohne das kann die Tags-Seite *„Charge 7"* nicht anzeigen. `update` bleibt, wie es ist: die Chargenzugehörigkeit ändert niemand im Portal.

**Kein `grant insert`.** `token` ist `not null` und nicht gewährt — jedes Insert eines Trainers scheitert, welche Spalten er auch nennt. Ein Insert-Recht wäre ein Versprechen ohne Deckung. Damit fällt auch die Policy `machine_tags_insert` aus `0016`; ihre dortige Begründung (*„der Grund, warum ein Studio sich nicht ohne Entwicklerhilfe einrichten liess"*) ist durch die Lieferung abgelöst. Das gehört als Kommentar in die Migration, sonst liest jemand `0016` und sucht den Weg.

Das Entziehen von `update` auf `token` ist nicht kosmetisch: ein Trainer, der schreiben dürfte, könnte einem Schild seines Studios einen selbst gewählten Token geben und die Beitritts-URL streuen.

### Was sich dadurch **nicht** ändert

`token_hash` behält Namen, Werte, Unique-Bedingung und Lesbarkeit. Unverändert bleiben deshalb:

`packages/domain/src/bootstrap.ts` (die App vergleicht offline weiter gegen Hashes), `packages/domain/src/tag-context.ts`, `apps/web/app/t/[token]/page.tsx`, `apps/web/app/api/v1/tags/[token]/context/route.ts`, `resolve_tag_fallback` aus `0021` und `0025`, `join_studio_by_tag` aus `0023`. `hashTagToken` bleibt im Repo und behält seine Unit-Tests.

Was sich ändert, ist einzig, **wer schreibt**: `token: <klartext>` statt `token_hash: hashTagToken(...)`.

---

## 2. Die Halde und die Lieferung

### `0027_tag_chargen.sql` — zwei Tabellen

```sql
create table public.tag_batches (
  id          uuid primary key default gen_random_uuid(),
  code        text not null unique,          -- lesbar, steht auf der Packung: '2026-08-A'
  kind        public.tag_kind not null,      -- zwei Erzeugnisse, zwei Chargen
  quantity    integer not null check (quantity > 0),
  supplier    text,
  ordered_on  date,
  scrapped_at timestamptz,                   -- Fehldruck: die ganze Charge faellt aus
  created_at  timestamptz not null default now()
);
alter table public.tag_batches enable row level security;
alter table public.tag_batches force  row level security;
-- Bewusst KEINE Policy: nur service_role (rolbypassrls) erreicht diese Tabelle.
-- Eine Charge ist ein Betreibergegenstand; kein Studio hat ein Wort dazu.
```

**Nachgezogen, Migration `0029`:** Task 8 (Betreiber-Fachschicht/Tags-Seite) brauchte `code`/`kind` der eigenen Charge lesbar fuer ein Studio, das nachweislich eine Lieferung oder einen eigenen Tag aus ihr hat -- reine "keine Policy" liess das nicht zu, auch fuer das verbundene Studio nicht. `0029` fuegt eine einzige, eng zugeschnittene SELECT-Policy hinzu: sichtbar nur ueber einen bestehenden Eintrag in `tag_shipments` oder `machine_tags`, die beide bereits `is_studio_staff`-gebunden sind. Ein unverbundenes Studio sieht weiterhin nichts -- genau das, was dieser Absatz beschreibt, gilt fuer den unverbundenen Fall unveraendert.

```sql
create table public.tag_shipments (
  id         uuid primary key default gen_random_uuid(),
  batch_id   uuid not null references public.tag_batches (id) on delete restrict,
  studio_id  uuid not null references public.studios     (id) on delete restrict,
  quantity   integer not null check (quantity > 0),
  shipped_on date not null default current_date,
  note       text,
  created_at timestamptz not null default now()
);
create index on public.tag_shipments (studio_id);
alter table public.tag_shipments enable row level security;
alter table public.tag_shipments force  row level security;

create policy tag_shipments_select on public.tag_shipments
  for select to authenticated
  using (public.is_studio_staff(studio_id));
```

`tag_shipments` ist die einzige der beiden Tabellen, die das Portal liest. Sie trägt die Zeile *„Lieferung vom 12. August · 100 Tags"* — und **benennt keinen einzigen Token** (Entscheidung 5).

`on delete restrict` auf beiden Fremdschlüsseln: eine Lieferung ist ein Vorgang der Vergangenheit. Ein Studio wird stillgelegt, nicht gelöscht — dieselbe Linie wie bei `machine_tags_machine_id_fkey` aus `0008`.

### `machine_tags` bekommt drei Änderungen

```sql
alter table public.machine_tags
  alter column studio_id drop not null,
  add column batch_id    uuid    not null references public.tag_batches (id) on delete restrict,
  add column batch_index integer not null check (batch_index >= 1),
  add constraint machine_tags_batch_index_key unique (batch_id, batch_index);

grant select (id, studio_id, machine_id, token_hash, status, kind,
              batch_id, batch_index, created_at, revoked_at)
  on public.machine_tags to authenticated;
```

Der erneuerte `select`-Grant ist kein Nachtrag, sondern Pflicht: `0026` konnte die beiden Spalten nicht nennen, weil es sie dort noch nicht gab.

`not null` ist gefahrlos, weil `0026` die Tabelle geleert hat. `batch_index` ist die auf dem Erzeugnis aufgedruckte laufende Nummer — das Ziel, ohne das *Sperren* auf der Tags-Seite ins Leere zeigt (Einrichtungs-Spec §1).

### Ein Constraint hält die Halde zusammen

```sql
alter table public.machine_tags
  add constraint machine_tags_halde
    check (studio_id is not null
           or (status in ('unassigned', 'revoked') and machine_id is null));
```

Vier Aussagen in einer Zeile:

- Eine Zeile ohne Studio hat kein Gerät.
- Eine Zeile ohne Studio ist nie `active` — weder als Gerätetag noch als Schild.
- Eine Zeile ohne Studio darf trotzdem `revoked` werden: verlorene Packung, Fehldruck vor dem Versand.
- Und weil eine studiolose Zeile nie aktiv ist, bleibt die Annahme `studio_id: string` in `getTagContext` wahr, ohne dass die Datei angefasst wird.

Der Constraint `machine_tags_machine_kind` aus Task 1 des Datenbankplans (`0022`) bleibt daneben unverändert gültig und wird nicht ersetzt.

### Warum die Halde keine eigene Tabelle bekommt

Der naheliegende Gegenentwurf wäre `tag_batch_items` mit den Tokens, aus dem beim Versand nach `machine_tags` kopiert wird. Dann bliebe `studio_id` `not null` und keine bestehende Abfrage müsste geprüft werden.

Der Preis wäre derselbe Token an zwei Orten und eine zweite Unique-Insel über den Tokenraum, die auseinanderlaufen kann. **Die teuren Fehler dieses Projekts kamen bisher aus doppelter Buchführung** — der Beispielbestand, der zwischen Member- und Portal-Artboards auseinanderlief, ist genau das im Kleinen. Eine nullbare Fremdschlüsselspalte ist billiger zu bewachen als zwei Tabellen, die dasselbe behaupten.

Dass `studio_id is null` gefahrlos ist, ist geprüft, nicht angenommen: `is_studio_member(null)` und `is_studio_staff(null)` liefern `false`, weil `m.studio_id = null` nie zutrifft. Eine Haldenzeile ist damit für jedes `authenticated`-Konto unsichtbar, ohne dass eine Policy angefasst wird. `getBootstrap` filtert zusätzlich auf `status = 'active'` und überspringt Zeilen ohne `machine_id` — Haldenzeilen fallen dort doppelt heraus.

### Die Zuordnung, je Sorte

| Sorte | Bei der Lieferung | Beim Scan vor dem Gerät |
| --- | --- | --- |
| `machine` | nur eine `tag_shipments`-Zeile; kein Token wird angefasst | `studio_id`, `machine_id`, `status='active'` |
| `studio` | `tag_shipments`-Zeile **und** die benannten Zeilen auf `studio_id` + `status='active'` | — |

Fünf Nummern eintippen für die Schilder, null Erfassung für die hundert Aufkleber.

### Der Vorrat rechnet sich ohne weitere Spalte

```
geliefert  = Σ tag_shipments.quantity   (Charge kind='machine', dieses Studio)
verbraucht = count(machine_tags)        (studio_id = X, kind='machine')
vorrätig   = geliefert − verbraucht
```

Ein Gerätetag bekommt sein `studio_id` ausschließlich beim Binden. Die Zählung ist damit definitionsgemäß richtig, auch wenn der Tag später gesperrt oder ersetzt wird — verbraucht ist verbraucht.

### Was dabei verloren geht

**Der Fehllieferungsschutz.** Kommt die Gerätepackung für Studio B bei Studio A an, bindet A sie klaglos ein; niemand liest *„gehört nicht zu eurem Studio"* und ruft an. Das ist der Preis von Entscheidung 3 und gehört benannt, nicht verschwiegen.

Für Aushangschilder gilt er nicht: die sind namentlich zugeordnet, und ein Schild in fremder Hand fällt in die Antwort *„Melde dich beim Betreiber."*

---

## 3. Die zwei Datenbankfunktionen

`0028_tag_binden.sql`. Beide `SECURITY DEFINER`, beide mit `set search_path = public, pg_temp`, beide mit dem vollständigen `revoke`/`grant`-Paar aus den Global Constraints des Datenbankplans — `revoke ... from public, anon, authenticated, service_role`, dann `grant execute ... to authenticated`.

### Warum es zwei sein müssen

Ein studioloser Tag ist per RLS unsichtbar. Der Sucher des Trainers sähe bei *„frischer Tag aus eurer Lieferung"* und bei *„fremder QR-Code"* dasselbe: nichts. Das sind aber Zeile 1 und Zeile 5 der Antworttabelle in Einrichtungs-Spec §4 — die eine führt zu *Verbinden*, die andere zu *„Neue Lieferung? Melde dich beim Betreiber."*

**Ohne Lesefunktion ist die Antworttabelle nicht baubar**, und der Sucher-Plan müsste dieses Schema wieder aufmachen. Deshalb gehört sie hierher, obwohl der Sucher selbst es nicht tut.

### `inspect_tag(p_token text, p_studio_id uuid)`

Rückgabe: `verdict text`, `batch_code text`, `batch_index integer`, `machine_id uuid`, `machine_label text`.

Ist der Aufrufer nicht `is_studio_staff(p_studio_id)`, lautet die Antwort `unbekannt` — nicht `unauthorized`, ohne die Tag-Zeile ueberhaupt anzusehen. Ein ungueltiges Tokenformat landet auf demselben `unbekannt`, aber ueber denselben Pfad wie ein unbekannter Token -- die Funktion unterscheidet das Format nicht vorab, sondern findet schlicht keine Zeile. Eine Abfrage mehr als eine vorab verworfene Anfrage, gleiche Antwort.

| Zeile in `machine_tags` | verdict | Antwort in §4 |
| --- | --- | --- |
| kein Treffer, oder Format ungültig | `unbekannt` | „Neue Lieferung? Melde dich beim Betreiber." |
| `kind='machine'`, studiolos, `unassigned`, Charge nicht verschrottet | `frei` | „Tag erkannt · Charge 7" → **Verbinden** |
| `kind='machine'`, eigenes Studio, gebunden, `active` | `vergeben` | „Dieser Tag gehört zu Beinpresse 7." |
| `kind='machine'`, `revoked`/`replaced`, oder Charge verschrottet | `gesperrt` | „Gesperrt bleibt gesperrt." |
| `kind='studio'`, eigenes Studio, `active` | `aushangschild` | „Das ist ein Aushangschild." |
| alles mit fremdem `studio_id`; jedes noch nicht gelieferte Schild | `unbekannt` | dieselbe eine Antwort |

**Die Reihenfolge der Prüfung ist Teil der Festlegung, nicht Geschmackssache.** Die Studiozugehörigkeit wird **zuerst** geprüft: ein gesperrter Gerätetag eines fremden Studios ist `unbekannt`, nicht `gesperrt`. Sonst verrät die Antwort, dass dieser Token anderswo existiert. Erst danach entscheiden Sorte und Status.

Die letzte Zeile trägt den Rest: **über ein fremdes Studio wird nie etwas verraten, auch nicht die Sorte.** Ein studioloses Schild in Trainerhand ist ein Versandfehler, und *„melde dich beim Betreiber"* ist dafür die richtige Antwort — es wäre ohnehin nicht gültig.

`batch_code`/`batch_index` werden bei jedem Verdikt gefuellt, das die Zeile bereits gefunden hat -- `frei`, `vergeben`, `gesperrt` und `aushangschild` gleichermassen; nur `unbekannt` liefert beides `null`, weil dort per Definition keine Zeile (oder keine zugaengliche) vorliegt. `machine_id`/`machine_label` bleiben `vergeben` vorbehalten. *„Tag erkannt · Charge 7"* bleibt damit wörtlich baubar: die Zeile kennt ihre **Herstell**charge über `batch_id`, unabhängig davon, an wen geliefert wurde.

### `bind_tag_to_machine(p_token text, p_machine_id uuid)`

Rückgabe: `verdict text`, `tag_id uuid`.

Sie leitet das Studio aus der **Maschine** ab und prüft `is_studio_staff` dagegen; ein `p_studio_id` von außen gibt es nicht — sonst wäre die Zuordnung von außen wählbar. Sie sperrt die Zeile mit `for update`, prüft dieselben Bedingungen wie `frei` noch einmal und setzt in einem Zug `studio_id`, `machine_id`, `status='active'`.

Erfolg ist `gebunden`. Jeder andere Ausgang liefert dasselbe Vokabular wie `inspect_tag` — damit der Sucher zwischen Ansehen und Verbinden nicht die Sprache wechselt, und damit das Rennen zweier Trainer an derselben Packung eine Antwort bekommt statt einer Constraint-Verletzung.

Das ist zugleich der Posten, den Einrichtungs-Spec §5 bereits als fehlend führt (*„es fehlt der Weg über den Token-Hash statt über die Tag-ID"*). Er wird hier größer, weil er jetzt auch das Studio vergibt.

---

## 4. Das Betreiberwerkzeug

### Wo es liegt

Die Logik in `packages/domain/src/chargen.ts`, als Unterpfad `@fitretro/domain/chargen` exportiert und **nicht** über `index.ts` — dieselbe Bauart, die `media.ts` in der `exports`-Karte schon hat. Sie nimmt wie alles in der Fachschicht einen `SupabaseClient` entgegen und hält keinen Schlüssel; wer einen Service-Client hineinreicht, entscheidet der Aufrufer.

Der Aufrufer ist eine dünne Schale `scripts/tags.ts`: Argumente lesen, Client bauen, Zeilen drucken.

**Neue devDependency: `tsx`**, plus `"tags": "tsx scripts/tags.ts"` in der Wurzel. `scripts/smoke-aasa.mjs` läuft als reines `.mjs` unter Node, aber diese Schale muss TypeScript aus dem Workspace importieren. Die Alternative — alles in `.mjs` — nähme dem einzigen Code im Repo, der mit `service_role` schreibt, die Typprüfung. Falscher Ort zum Sparen.

### Sechs Befehle

```
pnpm tags charge:anlegen      --code 2026-08-A --sorte machine --menge 1000 [--lieferant …] [--bestellt …]
pnpm tags charge:csv          --code 2026-08-A [--basis https://…] [--datei …]
pnpm tags charge:verschrotten --code 2026-08-A
pnpm tags lieferung           --charge 2026-08-A --studio <uuid|Name> --menge 100
pnpm tags lieferung           --charge 2026-08-S --studio <uuid|Name> --nummern 3-7
pnpm tags bestand             --studio <uuid|Name>
```

`--studio` nimmt eine UUID oder den genauen Namen; ist der Name nicht eindeutig, nennt der Fehler die Kandidaten. Ein siebter Befehl zum Auflisten der Studios erübrigt sich damit. `--nummern` nimmt Bereiche und Aufzählungen gemischt (`3-7`, `3,4,9`, `1-5,12`). `--basis` fällt auf die Umgebungsvariable `TAG_URL_BASE` zurück und ist Pflicht, wenn auch die fehlt — eine CSV mit halben URLs ist beim Lieferanten nicht reparierbar.

### Was die Befehle tun

**`charge:anlegen`** schreibt den Chargenkopf und *N* Zeilen mit `createTagToken()`, `batch_index` 1…N, `kind` aus der Charge, `status='unassigned'`, `studio_id` null. In Blöcken zu 500; ein Block, der an der Unique-Bedingung scheitert, wird neu gewürfelt statt abzubrechen. Bei 128 Bit ist das Papierkram, aber ein Abbruch mitten in einer Tausendercharge wäre teurer als die vier Zeilen.

**`charge:csv`** ist die Stelle, an der sich Entscheidung 1 auszahlt: `nummer,charge,sorte,token,url`, **jederzeit wiederholbar**. Die `url` ist `<basis>/t/<token>`; der Lieferant braucht sie zweimal, für den QR-Druck und für die NDEF-Programmierung des Chips. Die Datei ist das einzige Erzeugnis, das Tokens im Klartext zeigt — auf `stdout` erscheint kein einziger.

**`charge:verschrotten`** setzt `scrapped_at`. Danach liefert die Charge nichts mehr, und `inspect_tag` antwortet auf ihre Tokens `gesperrt`. Der Befehl existiert, weil die Spalte existiert: eine Spalte ohne Weg, sie zu setzen, ist genau der *„Scheck, den das Backend noch nicht einlösen kann"*, vor dem `2026-08-31-trainerportal-struktur-design.md` warnt.

**`lieferung`** ist die Stelle, an der die Sortentrennung zubeißt:

- `--menge` gilt nur für `kind='machine'` und schreibt **nur** eine `tag_shipments`-Zeile.
- `--nummern` gilt nur für `kind='studio'`, setzt auf den genannten Zeilen `studio_id` und `status='active'` und schreibt die Lieferzeile mit deren Anzahl.
- Beides zusammen, oder das jeweils falsche zur Sorte: `validation_failed`.
- `Σ Lieferungen + Menge > charge.quantity`: `conflict`. Sonst verspricht der Vorrat im Portal Aufkleber, die es nicht gibt.
- Genannte Nummern, die nicht existieren, nicht studiolos oder nicht `unassigned` sind: `conflict`, mit Nennung der betroffenen Nummern.
- Eine verschrottete Charge liefert nichts mehr.

**`bestand`** rechnet geliefert / verbraucht / vorrätig genau so, wie das Portal es tut, und ist die Gegenprobe zur Tags-Seite, ohne sich anmelden zu müssen.

### Zwei Schutzmaßnahmen in der Schale

Sie druckt vor jeder schreibenden Handlung das Ziel aus `SUPABASE_URL`, und bei allem, was nicht `127.0.0.1` ist, verlangt sie ein zusätzliches `--ja`. Dieses Werkzeug läuft irgendwann gegen das echte Projekt.

Die Fehlercodes sind die der Fachschicht — `validation_failed`, `unauthorized`, `not_found`, `conflict`, `internal` aus `packages/domain/src/errors.ts` — nicht selbst erfundene.

---

## 5. Was am Portal zurückgebaut und was ersetzt wird

### `createTag` stirbt in diesem Plan, nicht in einem späteren

Nach `0026` kann `createTag` nicht mehr laufen: `token_hash` ist generiert und `token` für `authenticated` nicht schreibbar. Das ist genau, was Entscheidung 2 der Einrichtungs-Spec will (*„im Portal entsteht kein Token mehr"*) — aber es macht den Rückbau **erzwungen** statt aufschiebbar. Die Einrichtungs-Spec §6 schreibt, der Rückbau sei *„ein eigener Plan mit eigener Testmatrix"*; das gilt nicht mehr, er wandert hierher.

Betroffene Stellen, vollständig:

| Stelle | Was geschieht |
| --- | --- |
| `packages/domain/src/catalog.ts` (`createTag`) | entfällt |
| `packages/domain/src/index.ts` | Export entfällt |
| `apps/web/app/portal/actions.ts:302` | Server Action entfällt |
| `apps/web/app/portal/[studioId]/TagAnlegen.tsx` | entfällt samt Aufrufstellen |
| `tests/integration/domain-catalog.test.ts` | zehn Aufrufe, ersetzt durch den Testhelfer |
| `e2e/trainerportal.spec.ts:119` | Schritt 5 des Einrichtungsgangs wird umgeschrieben |

Der E2E-Test liest den Token heute aus der Oberfläche ab (`getByTestId("tag-token")`) und benutzt ihn danach gegen `/api/v1/tags/<token>/context`. Künftig legt er über `service_role` eine Charge und eine Haldenzeile an — wie `e2e/tag-fallback.spec.ts` es für Tags bereits tut — und bindet über die Oberfläche.

### `TagZuweisen` bleibt und wird zum Rückfallweg

`tags/TagZuweisen.tsx` ist heute der **einzige** Weg im Portal, einen Tag an ein Gerät zu binden. Fiele er ersatzlos, könnte bis zum Sucher niemand mehr einen Tag verbinden — und sein bisheriges Mittel, ein Dropdown über die Tags des Studios, hat nach Entscheidung 3 nichts mehr zu listen: Haldenzeilen sind per RLS unsichtbar.

Er wird deshalb **vom Dropdown auf ein Textfeld umgebaut**: Token eintippen, `bind_tag_to_machine` aufrufen, die Vokabeln aus Abschnitt 3 anzeigen. Das ist der Sucher ohne Kamera, in ungefähr zwanzig Zeilen.

Zwei Dinge fallen damit zusammen:

- Der Sucher-Plan setzt später die Kamera davor, statt bei null anzufangen.
- Einrichtungs-Spec §7 führt *„Kamerafreigabe in mobilem Safari ist der einzige Ausfallpunkt ohne Rückfallweg."* **Der Rückfallweg wäre gebaut, bevor der Ausfallpunkt entsteht.**

### Die Vorratszeile auf der Tags-Seite

`Tags.dc.html` zeichnet *„Lieferung vom 12. August · 100 Tags · 97 vorrätig"* und die Lieferungsliste bereits. Ihre Quelle wird `tag_shipments` mit `tag_batches.code`, die Zahl die Rechnung aus Abschnitt 2. Keine Artboard-Änderung.

---

## 6. Der Testumbau

Der größte Posten dieses Plans, und in keiner der beiden Vorgängerspecs erwähnt.

`batch_id` und `batch_index` sind `not null` — **jeder Test, der eine `machine_tags`-Zeile einfügt, braucht ab `0027` erst eine Charge.** Zusammen mit `token` statt `token_hash` betrifft das:

`tests/integration/`: `rls-machine-tags.test.ts`, `rls-machine-tags-write.test.ts`, `rls-machines.test.ts`, `domain-bootstrap.test.ts`, `domain-tag-context.test.ts`, `domain-catalog.test.ts`, `api-tag-context.test.ts`, `resolve-tag-fallback.test.ts`, `fallback-inhalt.test.ts` — dazu `e2e/tag-fallback.spec.ts` und die drei Dateien, die der Datenbankplan neu anlegt.

**Die Antwort ist ein Helfer** neben `helpers/clients.ts`: `tests/integration/helpers/tags.ts` mit `chargeFuerTest(admin, kind)` und `tagAnlegen(admin, {...})`. Danach ist die Umstellung mechanisch, und die nächste Schemaänderung an `machine_tags` kostet eine Datei statt dreizehn.

**Zwei Dateien ändern ihre Aussage, nicht nur ihre Form:**

- `rls-machine-tags-write.test.ts` prüft heute die Insert-Policy aus `0016`, die wegfällt. Sie prüft künftig das Gegenteil: dass `authenticated` **nicht** einfügen kann.
- Neu und ohne Vorbild: dass ein Trainer `select token` auf das **eigene** Studio nicht darf, und `update token` ebenso wenig. Das ist die ganze Sicherheitseigenschaft aus Entscheidung 1; ohne diesen Test ist sie eine Behauptung.

Dazu je Zeile der Antworttabelle aus Abschnitt 3 ein Test gegen `inspect_tag`, und für `bind_tag_to_machine` mindestens: Erfolg, fremdes Studio, bereits gebunden, falsche Sorte, verschrottete Charge.

---

## 7. Reihenfolge und Aufgaben

**Numerisch, Datenbankplan zuerst.** `0022`–`0025`, dann `0026`–`0028`. `0027` baut auf `tag_kind` und dem Constraint aus Task 1 auf. Den Datenbankplan umzunummerieren, nur damit seine drei neuen Testdateien einmal statt zweimal geschrieben werden, ist ein schlechter Tausch: 45 KB Plan neu durchnummerieren gegen dreimal `token_hash:` → `token:`.

| | Aufgabe | Erzeugnis |
| --- | --- | --- |
| 1 | Testhelfer und Fixture-Umbau | `helpers/tags.ts`, dreizehn Dateien umgestellt |
| 2 | Migration `0026` — Klartext, generierter Hash, Spaltenrechte | + Test: Trainer liest und schreibt `token` nicht |
| 3 | `createTag` und die Erzeugen-Oberfläche zurückbauen | `catalog.ts`, `index.ts`, `actions.ts`, `TagAnlegen.tsx`, E2E umgeschrieben |
| 4 | Migration `0027` — Chargen, Lieferungen, Halde | + RLS-Tests auf `tag_batches` und `tag_shipments` |
| 5 | Migration `0028` — `inspect_tag`, `bind_tag_to_machine` | + Test je Zeile der Antworttabelle |
| 6 | `chargen.ts` und `scripts/tags.ts` | + `tag-chargen.test.ts` gegen echtes Postgres |
| 7 | `TagZuweisen` auf Token-Eingabe umbauen | Rückfallweg für den Sucher |
| 8 | Vorratszeile auf der Tags-Seite aus `tag_shipments` | „Lieferung vom 12. August · 100 Tags · 97 vorrätig" |

Aufgabe 1 muss vor 2 liegen, sonst wird derselbe Fixture-Code zweimal angefasst. Aufgabe 3 muss unmittelbar auf 2 folgen — dazwischen ist das Repo nicht übersetzbar.

---

## 8. Was dieser Plan nicht baut

**Den Sucher.** Kamera, Decoder im Browser, der Fünfschritt vor dem Gerät. Bleibt der einzige echte Neubau und bekommt einen eigenen Plan; sein Backend steht danach vollständig.

**Das Modell am Telefon.** Erweiterung, Einrichtungs-Spec §5.

**Eine Ratenbegrenzung** auf `join_studio_by_tag`. Offen, `2026-09-01-scan-beitritt-design.md` §7.

**Einen Bestellweg im Portal.** Der leere Vorrat mitten in der Halle ist gezeichnet, die Nachbestellung nicht. Bleibt eine Betreiberfrage.

---

## 9. Nachträge an die bestehenden Specs

Damit sich am Ende nicht wieder drei Dokumente widersprechen — die Lehre aus `2026-09-01-konflikte-scan-und-einrichtung.md`:

**`2026-09-01-einrichtung-am-geraet-design.md`**

| § | Nachtrag |
| --- | --- |
| §1 *„Die fehlenden Spalten"* | Aus einer Migration mit zwei Spalten werden drei Migrationen: `0026` Tokenraum, `0027` Chargen, `0028` Funktionen. Die Halde liegt in `machine_tags` mit nullbarem `studio_id`. |
| §1 *„Wer welchen Tag bekommt, entscheidet die Charge"* | Gilt für Aushangschilder. Gerätetags kommen studiolos und lernen ihr Studio beim Scan; der Fehllieferungsschutz entfällt, benannt. |
| §4 Zeile 5 | *„Charge nicht zugeordnet"* entfällt als Fall — eine studiolose Charge **ist** der Normalzustand, aus dem gebunden wird. Die Zeile behält ihre beiden anderen Fälle. |
| §5 | Zeile *„Chargenspalte und Schildnummer"* wird ersetzt; Zeile *„Tag binden per Scan"* zeigt auf `bind_tag_to_machine` und ist damit gebaut, nicht mehr offen. |
| §6 | Der Rückbau ist **nicht** mehr ein eigener Plan: `0026` erzwingt ihn. `TagZuweisen.tsx` entfällt nicht, sondern wird zum Rückfallweg. |
| §7 | Der Punkt *„Kamerafreigabe … einziger Ausfallpunkt ohne Rückfallweg"* ist entschärft, und die Druckmaße sind seit dem 3. September gemessen — 15 mm genügen am Gerät, der Aushang bleibt ungeprüft. Bleibt offen: lesbare Chargennummer, leerer Vorrat, Nummernvergabe. |

**`2026-09-01-scan-beitritt-datenbank.md`** — Global Constraints: der Absatz *„Der Klartext-Token existiert genau einmal"* fällt ersatzlos. An seine Stelle tritt: *der Token steht im Klartext in `machine_tags.token`, ist für `authenticated` weder les- noch schreibbar, und `token_hash` ist eine generierte Spalte.* Der Satz über die belegten Nummern wird auf `0026`–`0029` erweitert.

**`2026-09-01-scan-beitritt-design.md`** — unverändert. `join_studio_by_tag`, der Tokenraum als Begriff und der Ersatz-Constraint aus §1 tragen dieses Modell unangetastet.

---

## 10. Offene Punkte

- **Wie viele Aushangschilder pro Studio?** Der Entwurf zeigt fünf. Die Zahl ist nirgends festgelegt und entscheidet, ob das Eintippen von Nummern zumutbar bleibt. Ab etwa zwanzig braucht `lieferung` einen Bereichsausdruck statt einer Aufzählung — `--nummern 3-7` deckt das bereits ab, aber die Ergonomie ist ungeprüft.
- **Chargengröße gegen Lieferungsgröße.** Der Entwurf nimmt an, dass aus einer Tausendercharge zehn Hunderterlieferungen werden. Ob der Drucker in Tausendern arbeitet, ist Beschaffung und nicht entschieden.
- **`replaced` ist unbenutzt.** Der Status existiert seit `0002`, und kein Weg setzt ihn — auch dieser Plan nicht. Ein ersetzter Tag wird heute `revoked`, der neue frisch gebunden. Entweder bekommt `replaced` einen Weg oder er fällt.
- **Kein Weg zurück in die Halde.** Ein an das falsche Gerät gebundener Tag lässt sich nur sperren, nicht lösen. Vermutlich richtig — er klebt physisch —, aber es ist eine Annahme, keine Entscheidung.
