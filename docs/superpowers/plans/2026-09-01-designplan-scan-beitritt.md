# Designplan — Beitritt durch Scannen

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Die acht Bildschirme zeichnen, die den Beitritt per Scan tragen — zwei neu, sechs geändert, auf zwei Canvases.

**Architecture:** Artboards sind eigenständige `.dc.html`-Dateien ohne gemeinsame Laufzeit. Die sechs Einstiegs-Artboards der Member-App entstehen aus `gen_auth.py` über die Bausteine in `build.py`; die übrigen 26 sind handgeschriebene, formatierte HTML-Dateien und werden gezielt bearbeitet. `canvas.json` legt Position, Titel und Seite fest, `seed.sh` baut daraus die Canvas-Datei und prüft sie.

**Tech Stack:** Python 2/3-kompatible Generatorskripte (`io.open`, `%`-Formatierung), statisches HTML mit Inline-Styles, Node-Seeder aus der `design`-Skill.

**Spec:** `docs/superpowers/specs/2026-09-01-scan-beitritt-design.md`

## Global Constraints

- **Genau eine Akzentfläche je Bildschirm.** `#D4FF3F` als Fläche darf pro Artboard nur einmal vorkommen. Ein Akzent*rand* (`FIELD_FOCUS`, Sucherecken) zählt nicht dagegen — so steht es im Kommentar über `FIELD` in `build.py`.
- **Kein Scheinrahmen.** Keine gemalte iOS-Statusleiste, keine gemalte Tastatur, keine gemalte Browserleiste. Freiraum oben kommt aus `spacer_top()` (54 px).
- **Maße Member-App:** Rahmen 393 × 852. Seitenrand 28 px auf Einstiegs-Bildschirmen, 20 px auf Inhalts-Bildschirmen. Hauptaktion 64 px hoch, `border-radius: 16`. Nebenaktion 52 px, `border-radius: 14`, Umriss. Feld 58 px, `border-radius: 14`.
- **Farben:** Grund `#0A0B0D`, Fläche `#14161A`, Linie `#2A2E36`, Text `#F2F4F7`, gedämpft `#9BA3AF`, blass `#5C636E`, Akzent `#D4FF3F`, destruktiv `#FF5A4E`.
- **Schrift:** Archivo. Bildschirmtitel 32 px, `font-weight: 900`, Versalien, `letter-spacing: -.03em`. Alle Ziffern tabellarisch (`class="num"`).
- **Keine Tab-Leiste auf der Seite „Zugang".** Ohne Studio gibt es nichts, wohin man wechseln könnte.
- **Beispieldaten bleiben durchgängig:** Mitglied `Lena Wagner`, `lena.wagner@example.de`, Studios `Kraftwerk Nord` und `Südbad Fitness`, Gerät `Beinpresse`, Gerätenummer `07`.
- **`seed.sh` braucht `DESIGN_SKILL`** — den Pfad zur `design`-Skill. Ohne die Variable bricht es mit einer Meldung ab, das ist kein Fehler des Plans.

---

### Task 1: Zugang 03 umdrehen, Zugang 05 Scanner anlegen

**Files:**
- Modify: `docs/superpowers/design/member/gen_auth.py` (Abschnitt `MemberKeinStudio`, ab der Zeile `# ========================================================== MemberKeinStudio`)
- Produces: `docs/superpowers/design/member/MemberKeinStudio.dc.html`, `docs/superpowers/design/member/MemberScanner.dc.html`

**Interfaces:**
- Consumes: aus `build.py` — `NOTE_FAINT`, `PRIMARY`, `NEBEN`, `schreibe`, `kopf_marke`, `kopf_zurueck`, `titel`, `feld`, `ph`, `spacer_top`, `fuellen`
- Produces: die Dateinamen `MemberKeinStudio.dc.html` und **`MemberScanner.dc.html`** — Task 5 trägt beide in `canvas.json` ein und verlässt sich auf genau diese Schreibweise.

- [ ] **Step 1: Zwei Zeichen-Helfer in `gen_auth.py` ergänzen**

Direkt unter die vorhandene Funktion `zeile_svg` setzen:

```python
def qr_svg(groesse=22, farbe='#0A0B0D'):
    """QR-Umriss fuer die Hauptaktion. Steht auf der Akzentflaeche, ist
    deshalb dunkel -- nicht volt auf volt."""
    return ('<svg width="%d" height="%d" viewBox="0 0 24 24" fill="none" stroke="%s" '
            'stroke-width="2" stroke-linecap="round" stroke-linejoin="round">'
            '<rect x="3.5" y="3.5" width="6.5" height="6.5" rx="1.4"/>'
            '<rect x="14" y="3.5" width="6.5" height="6.5" rx="1.4"/>'
            '<rect x="3.5" y="14" width="6.5" height="6.5" rx="1.4"/>'
            '<path d="M14 14h3.2v3.2H14z"/><path d="M20.5 14v6.5H14"/></svg>'
            % (groesse, groesse, farbe))


def sucher_ecke(pos):
    """Eine der vier Sucherecken. Bewusst kein geschlossener Rahmen: ein
    Rahmen sieht aus wie eine Flaeche, die etwas verdeckt. Vier Winkel
    zeigen den Ausschnitt, ohne ihn zuzumachen. Rand, keine Flaeche --
    zaehlt nicht gegen die eine Akzentflaeche je Screen."""
    kanten = {
        'lo': 'top: 0; left: 0; border-top: 3px solid #D4FF3F; border-left: 3px solid #D4FF3F; border-top-left-radius: 15px;',
        'ro': 'top: 0; right: 0; border-top: 3px solid #D4FF3F; border-right: 3px solid #D4FF3F; border-top-right-radius: 15px;',
        'lu': 'bottom: 0; left: 0; border-bottom: 3px solid #D4FF3F; border-left: 3px solid #D4FF3F; border-bottom-left-radius: 15px;',
        'ru': 'bottom: 0; right: 0; border-bottom: 3px solid #D4FF3F; border-right: 3px solid #D4FF3F; border-bottom-right-radius: 15px;',
    }[pos]
    return '<div style="position: absolute; width: 44px; height: 44px; %s"></div>' % kanten
```

- [ ] **Step 2: Den Abschnitt `MemberKeinStudio` ersetzen**

Der ganze Block von `kein_studio = spacer_top() + kopf_marke()` bis einschließlich `schreibe('MemberKeinStudio.dc.html', ph(kein_studio))` wird ersetzt. Der Kommentar darüber wird mitgetauscht, weil er den alten Aufbau beschreibt:

```python
# ========================================================== MemberKeinStudio
# Der wichtigste der sechs: was ein frisch registriertes Mitglied sieht.
# Keine Tab-Leiste -- es gibt nichts, wohin man wechseln koennte.
#
# Der Scan ist die Hauptaktion und traegt die eine Akzentflaeche. Das
# Code-Feld bleibt als zweiter Weg, verliert dabei aber den Akzent an
# den Scan: zwei Flaechen wuerden beide behaupten, DER Weg zu sein.
kein_studio = spacer_top() + kopf_marke()
kein_studio += titel('Noch kein Studio',
                     'gymodo gehört zu einem Studio. Scanne den Code, der dort aushängt — '
                     'oder den Aufkleber an jedem Gerät.', top=40)
kein_studio += ("""
  <div style="flex: none; padding: 26px 28px 0;">
    <div style="%s gap: 11px;">%s<span>Code im Studio scannen</span></div>
  </div>
""" % (PRIMARY, qr_svg()))
kein_studio += ('<div style="flex: none; padding: 11px 28px 0;">'
                '<div style="%s text-align: center;">Aushang am Eingang oder Aufkleber am Gerät.</div></div>'
                % NOTE_FAINT)
kein_studio += '<div style="flex: none; margin: 26px 28px 0;" class="sep"></div>'
kein_studio += ('<div style="flex: none; padding: 22px 28px 0;">'
                '<span class="eyebrow">Kein Code zur Hand?</span></div>')
kein_studio += feld('Studio-Code',
                    '<span class="num" style="font-size: 18px; letter-spacing: .08em;">KWNORD-7F2X</span>',
                    monospace=True, top=9)
kein_studio += ('<div style="flex: none; padding: 12px 28px 0;"><div style="%s">Beitreten</div></div>' % NEBEN)
kein_studio += fuellen()
kein_studio += ('<div style="flex: none; padding: 0 28px 20px;">'
                '<div style="%s text-align: center;">Den Code bekommst du an der Theke.</div></div>'
                % NOTE_FAINT)
schreibe('MemberKeinStudio.dc.html', ph(kein_studio))
```

- [ ] **Step 3: Den Scanner als neuen Abschnitt ans Ende von `gen_auth.py` anfügen**

Nach dem Block `MemberPasswortAendern`, als letzter Abschnitt der Datei:

```python
# ============================================================= MemberScanner
# Der Sucher, den Zugang 03 oeffnet. Es ist derselbe Scanner wie in
# "Training -> Geraet finden" (App 15), aber ohne Tab-Leiste: die Seite
# Zugang hat keine. Eigenes Artboard statt eines Verweises -- "wie 15,
# nur anders" wird beim Bauen verlaesslich falsch gelesen.
#
# Keine Akzentflaeche auf diesem Screen. Die vier Sucherecken sind
# Raender; die einzige Aktion unten ist eine Nebenaktion. Ein Screen
# darf hoechstens eine Akzentflaeche haben, nicht mindestens eine.
scanner = spacer_top() + kopf_zurueck()
scanner += titel('Code scannen',
                 'Halte die Kamera auf den Aushang oder auf den Aufkleber am Gerät.', top=26)
scanner += ("""
  <div style="flex: none; margin: 30px 28px 0; height: 330px; border-radius: 18px;
              background: #14161A; border: 1px solid #2A2E36; position: relative;
              display: flex; align-items: center; justify-content: center;">
    <div style="position: relative; width: 206px; height: 206px;">%s%s%s%s</div>
  </div>
""" % (sucher_ecke('lo'), sucher_ecke('ro'), sucher_ecke('lu'), sucher_ecke('ru')))
scanner += ("""
  <div style="flex: none; margin: 18px 28px 0; background: #14161A; border: 1px solid #2A2E36;
              border-radius: 12px; padding: 14px 16px; display: flex; gap: 12px; align-items: flex-start;">
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#9BA3AF" stroke-width="2"
         stroke-linecap="round" style="flex: none; margin-top: 1px;"><path d="M7.5 8.5a5 5 0 0 1 0 7"/><path d="M11.5 5.5a10 10 0 0 1 0 13"/><path d="M15.5 2.5a15 15 0 0 1 0 19"/></svg>
    <div style="%s">Klebt ein NFC-Aufkleber am Gerät, genügt es, das Telefon daran zu halten — ohne diesen Bildschirm.</div>
  </div>
""" % NOTE)
scanner += fuellen()
scanner += ('<div style="flex: none; padding: 0 28px 20px;"><div style="%s">Code stattdessen eingeben</div></div>'
            % NEBEN)
schreibe('MemberScanner.dc.html', ph(scanner))
```

- [ ] **Step 4: `NOTE` in den Import aufnehmen**

`gen_auth.py` importiert `NOTE` bereits in der ersten Importzeile. Prüfen, dass die Zeile unverändert so lautet:

```python
from build import (NOTE, NOTE_FAINT, FIELD, FIELD_FOCUS, PRIMARY, PRIMARY_OFF, NEBEN,
                    schreibe, kopf_marke, kopf_zurueck, titel, feld, tabs, ph, spacer_top, fuellen)
```

- [ ] **Step 5: Generator laufen lassen**

```bash
cd docs/superpowers/design/member
python gen_auth.py
```

Erwartet: sieben Zeilen `geschrieben: …`, darunter `geschrieben: MemberKeinStudio.dc.html` und `geschrieben: MemberScanner.dc.html`.

- [ ] **Step 6: Die eine Akzentfläche je Datei nachzählen**

```bash
cd docs/superpowers/design/member
grep -c "background: #D4FF3F" MemberKeinStudio.dc.html MemberScanner.dc.html
```

Erwartet: `MemberKeinStudio.dc.html:2` und `MemberScanner.dc.html:0`.

**Die 2 ist richtig, nicht der Fehler:** `kopf_marke()` trägt den 7 px großen Markenpunkt mit derselben Farbe, dazu kommt die Hauptaktion. Der Scanner nutzt `kopf_zurueck()` und hat keinen Punkt, also 0. Bei `3` in KeinStudio trägt das Code-Feld noch Akzent — dann steht in Step 2 versehentlich `PRIMARY` statt `NEBEN`.

- [ ] **Step 7: Commit**

```bash
git add docs/superpowers/design/member/gen_auth.py \
        docs/superpowers/design/member/MemberKeinStudio.dc.html \
        docs/superpowers/design/member/MemberScanner.dc.html
git commit -m "design: Zugang 03 auf Scannen gedreht, Scanner als 05"
```

---

### Task 2: Home und Home-leer — Beitritts- und Wechselzeile

**Files:**
- Modify: `docs/superpowers/design/member/Home.dc.html:29-32`
- Modify: `docs/superpowers/design/member/HomeLeer.dc.html` (dieselbe Kopfzeile, gleiche Stelle)

**Interfaces:**
- Consumes: nichts aus vorigen Tasks. Beide Dateien sind handgeschrieben, es gibt keinen Generator dafür.
- Produces: nichts, worauf spätere Tasks zugreifen.

Beide Dateien tragen identisch diesen Block:

```html
  <div style="flex: none; padding: 14px 20px 0; display: flex; align-items: baseline; justify-content: space-between">
    <div style="font-size: 32px; font-weight: 900; letter-spacing: -.03em; text-transform: uppercase; line-height: 1">Hallo Lena</div>
    <div class="eyebrow">Kraftwerk Nord</div>
  </div>
```

- [ ] **Step 1: In `Home.dc.html` die Beitrittszeile direkt hinter diesen Block setzen**

Unmittelbar nach dem `</div>`, das die Kopfzeile schließt, und vor dem Kommentar `<!-- Kopfzeile -->`:

```html
  <!-- Einmalige Folge eines Scans. Beitritt und Studiowechsel passieren ohne
       Rueckfrage; sichtbar muessen sie trotzdem sein, sonst ist eine ploetzlich
       andere Kursliste ein Fehler statt einer Folge. Verschwindet beim naechsten
       Start -- deshalb eine Zeile und keine Karte mit Schliessen-Kreuz. -->
  <div style="flex: none; margin: 14px 20px 0; background: rgba(212,255,63,.09); border: 1px solid #D4FF3F55; border-radius: 12px; padding: 11px 14px; display: flex; gap: 10px; align-items: center">
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#D4FF3F" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" style="flex: none"><path d="m4.5 12.5 5 5 10-11"/></svg>
    <div style="font-size: 13px; line-height: 1.45; color: #F2F4F7">Du gehörst jetzt zu <strong style="font-weight: 800">Kraftwerk Nord</strong>.</div>
  </div>
```

- [ ] **Step 2: In `HomeLeer.dc.html` an derselben Stelle die Wechselzeile setzen**

Zwei Artboards, zwei Zustände — dieselbe Zeile in beiden zu zeigen, verschenkt den zweiten:

```html
  <!-- Der zweite der beiden Zustaende aus Spec 2: nicht der Beitritt, sondern
       der stillschweigende Wechsel zwischen zwei Studios. -->
  <div style="flex: none; margin: 14px 20px 0; background: rgba(212,255,63,.09); border: 1px solid #D4FF3F55; border-radius: 12px; padding: 11px 14px; display: flex; gap: 10px; align-items: center">
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#D4FF3F" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" style="flex: none"><path d="M4 8h13l-3.5-3.5M20 16H7l3.5 3.5"/></svg>
    <div style="font-size: 13px; line-height: 1.45; color: #F2F4F7"><strong style="font-weight: 800">Südbad Fitness</strong> ist jetzt aktiv.</div>
  </div>
```

- [ ] **Step 3: In `HomeLeer.dc.html` die Kopfzeile auf das gewechselte Studio ziehen**

Sonst widerspricht die Zeile der Überschrift daneben. In `HomeLeer.dc.html`, und **nur dort**:

```html
    <div class="eyebrow">Südbad Fitness</div>
```

- [ ] **Step 4: Sichtprüfung auf Überlauf**

```bash
cd docs/superpowers/design/member
grep -c "flex-grow: 1" Home.dc.html HomeLeer.dc.html
```

Erwartet: je mindestens `1`. Der Füller fängt die zusätzlichen ~62 px auf. Fällt die Zahl auf `0`, ist der Füller versehentlich überschrieben worden — dann die Einfügung zurücknehmen und neu setzen.

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/design/member/Home.dc.html docs/superpowers/design/member/HomeLeer.dc.html
git commit -m "design: Beitritts- und Wechselzeile auf Home"
```

---

### Task 3: Profil — Abschnitt Studios

**Files:**
- Modify: `docs/superpowers/design/member/Profil.dc.html`

**Interfaces:**
- Consumes: die Klassen `card`, `row`, `sep`, `eyebrow` aus dem `<helmet>`-Block derselben Datei.
- Produces: nichts, worauf spätere Tasks zugreifen.

**Achtung, gemessene Enge.** Profil trägt schon Konto-Karte, *Beim Training*, *Deine Daten*, Abmelden und Tab-Leiste auf 852 px. Der neue Abschnitt kostet rund 130 px. Step 4 prüft das, Step 5 hat den benannten Ausweichweg.

- [ ] **Step 1: Den Abschnitt `Studios` direkt nach der Konto-Karte einfügen**

Anker ist das Ende des ersten `padding: 20px 20px 0`-Blocks, der auf die Zeile *Passwort ändern* folgt. Direkt davor steht der Abschnitt *Beim Training* mit `<div class="eyebrow">Beim Training</div>`. Der neue Block kommt **davor**:

```html
  <!-- Bei genau einer Mitgliedschaft -- dem Normalfall -- ist das eine ruhige
       Zeile ohne Auswahl. Der Mehrstudio-Fall kostet genau diesen Abschnitt.
       Verlassen steht je Zeile, nicht als Sammelaktion: es betrifft immer
       genau ein Studio, und welches, muss ablesbar sein. -->
  <div style="flex: none; padding: 20px 20px 0; display: flex; flex-direction: column; gap: 10px">
    <div class="eyebrow">Studios</div>
    <div class="card">
      <div class="row">
        <span style="width: 7px; height: 7px; border-radius: 50%; background: #D4FF3F; display: inline-block; flex: none"></span>
        <span style="flex-grow: 1; font-size: 15px; font-weight: 700">Kraftwerk Nord</span>
        <span style="font-size: 12px; font-weight: 700; color: #FF5A4E; flex: none">Verlassen</span>
      </div>
      <div class="sep"></div>
      <div class="row">
        <span style="width: 7px; height: 7px; border-radius: 50%; background: #2A2E36; display: inline-block; flex: none"></span>
        <span style="flex-grow: 1; font-size: 15px; font-weight: 700; color: #9BA3AF">Südbad Fitness</span>
        <span style="font-size: 12px; font-weight: 700; color: #FF5A4E; flex: none">Verlassen</span>
      </div>
    </div>
    <div style="font-size: 12px; line-height: 1.5; color: #5C636E">Tippen wechselt. Ein Scan im anderen Studio wechselt von selbst.</div>
  </div>
```

- [ ] **Step 2: Den Studionamen in der Konto-Karte entfernen**

Er steht jetzt eine Karte tiefer, und zwar mit Zustand. Zweimal dieselbe Angabe, einmal ohne Zustand, ist die schlechtere:

```html
        <div style="font-size: 12px; color: #5C636E">lena.wagner@example.de</div>
```

ersetzt

```html
        <div style="font-size: 12px; color: #5C636E">lena.wagner@example.de · Kraftwerk Nord</div>
```

- [ ] **Step 3: Die Fußzeile unverändert lassen**

`gymodo 0.1 · Kraftwerk Nord` am unteren Rand bleibt. Sie nennt das aktive Studio im Zusammenhang mit der Version — das ist eine Herkunftsangabe, keine Zustandsanzeige, und sie doppelt den neuen Abschnitt nicht.

- [ ] **Step 4: Überlauf prüfen**

```bash
cd docs/superpowers/design/member
python -c "import io,re; s=io.open('Profil.dc.html',encoding='utf-8').read(); print('Abmelden:', 'Abmelden' in s); print('Tabs:', s.count('class=\"tabs\"'))"
```

Erwartet: `Abmelden: True`, `Tabs: 1`. Das prüft die Struktur, nicht die Höhe — die Höhe prüft Step 5 am gerenderten Artboard.

- [ ] **Step 5: Am gerenderten Artboard nachsehen, mit benanntem Ausweichweg**

Die Datei im Browser öffnen und nachsehen, ob *Abmelden* und die Tab-Leiste noch sichtbar sind. `.ph` hat `overflow: hidden` — was nicht passt, verschwindet lautlos, es gibt keine Fehlermeldung.

Wenn etwas fehlt: den Absatz in *Deine Daten* auf den ersten Satz kürzen. Aus

```html
        <div style="font-size: 13px; line-height: 1.55; color: #9BA3AF">gymodo misst nichts. Gespeichert wird nur, was du selbst bestätigst: Einstellwerte, Sätze und ob ein Trainer dabei war. Einweisungsvideos gehören <strong style="color: #F2F4F7">Kraftwerk Nord</strong>.</div>
```

wird

```html
        <div style="font-size: 13px; line-height: 1.55; color: #9BA3AF">gymodo misst nichts. Gespeichert wird nur, was du selbst bestätigst — Einstellwerte, Sätze, ob ein Trainer dabei war.</div>
```

Das spart zwei Zeilen (~42 px). **Der Satz zur Datenschutzgrenze bleibt dabei stehen** — gekürzt wird der Zusatz über die Videorechte, nicht die Aussage, dass nichts gemessen wird.

- [ ] **Step 6: Commit**

```bash
git add docs/superpowers/design/member/Profil.dc.html
git commit -m "design: Profil bekommt den Abschnitt Studios"
```

---

### Task 4: Web-Fallback 25 ergänzen, 27 Aushang anlegen

**Files:**
- Modify: `docs/superpowers/design/member/FallbackGeraet.dc.html`
- Create: `docs/superpowers/design/member/FallbackAushang.dc.html`

**Interfaces:**
- Consumes: den `<helmet>`-Block aus `FallbackGeraet.dc.html`, der für die neue Datei kopiert wird — Artboards teilen zur Laufzeit nichts.
- Produces: den Dateinamen **`FallbackAushang.dc.html`** für Task 5.

- [ ] **Step 1: In `FallbackGeraet.dc.html` den zweiten Scan in die Aufforderungskarte schreiben**

Die Karte am Fuß endet heute mit `App laden` und einer blassen Zeile über Android. Ohne den Satz über den zweiten Scan ist der Kaltstart eine Sackgasse. Die letzte Zeile der Karte

```html
    <div style="font-size: 11px; line-height: 1.5; color: #5C636E">Zurzeit nur für iPhone. Die Einweisung oben funktioniert auf jedem Gerät und ohne App.</div>
```

wird ersetzt durch

```html
    <div style="font-size: 12px; line-height: 1.5; color: #9BA3AF">Nach dem Laden diesen Code hier noch einmal scannen — dann bist du bei <strong style="color: #F2F4F7; font-weight: 700">Kraftwerk Nord</strong> angemeldet.</div>
    <div style="font-size: 11px; line-height: 1.5; color: #5C636E">Zurzeit nur für iPhone. Die Einweisung oben funktioniert auf jedem Gerät und ohne App.</div>
```

- [ ] **Step 2: Prüfen, dass der Studioname oben schon steht**

`FallbackGeraet.dc.html` trägt in der Kopfleiste bereits `<span class="eyebrow" style="font-size: 10px">Kraftwerk Nord</span>`. Es ist **nichts zu ändern** — die Spec verlangt den Studionamen ganz oben, und er steht dort. Diesen Schritt nur bestätigen, nicht bearbeiten.

- [ ] **Step 3: `FallbackAushang.dc.html` anlegen**

Ganze Datei, einschließlich `<helmet>` — Artboards teilen nichts:

```html
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Archivo:wght@400;500;600;700;800;900&display=swap">
  <style>
    * { box-sizing: border-box; }
    body { margin: 0; background: #0A0B0D; color: #F2F4F7; font-family: Archivo, -apple-system, "Segoe UI", system-ui, sans-serif; -webkit-font-smoothing: antialiased; font-variant-numeric: tabular-nums; }
    .ph { width: 390px; height: 844px; background: #0A0B0D; color: #F2F4F7; display: flex; flex-direction: column; overflow: hidden; }
    .eyebrow { font-size: 11px; font-weight: 800; letter-spacing: .14em; text-transform: uppercase; color: #9BA3AF; }
    .num { font-variant-numeric: tabular-nums; font-weight: 900; letter-spacing: -.03em; }
  </style>
</helmet>
<div class="ph">

  <!-- Browser-Leiste des Nutzers zeichnen wir nicht; die Seite beginnt hier -->
  <div style="flex: none; height: 52px; padding: 0 20px; display: flex; align-items: center; justify-content: space-between; border-bottom: 1px solid #2A2E36">
    <div style="display: flex; align-items: baseline; gap: 3px">
      <span style="font-size: 18px; font-weight: 800; letter-spacing: -.04em">gymodo</span>
      <span style="width: 5px; height: 5px; border-radius: 50%; background: #D4FF3F; display: inline-block"></span>
    </div>
    <span class="eyebrow" style="font-size: 10px">Kraftwerk Nord</span>
  </div>

  <!-- Ein Aushang-Token zeigt kein Geraet. Also zeigt die Seite, was es
       stattdessen gibt -- nicht eine Geraeteseite ohne Geraet. -->
  <div style="flex: none; padding: 26px 20px 0; display: flex; flex-direction: column; gap: 6px">
    <span class="eyebrow">Aushang</span>
    <div style="font-size: 30px; font-weight: 800; letter-spacing: -.03em; text-transform: uppercase; line-height: 1.02">Kraftwerk Nord</div>
    <div style="font-size: 15px; color: #9BA3AF; font-weight: 500">Dein Studio arbeitet mit gymodo.</div>
  </div>

  <div style="flex: none; padding: 26px 20px 0; display: flex; flex-direction: column; gap: 12px">
    <div style="display: flex; gap: 12px; align-items: flex-start">
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#D4FF3F" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="flex: none; margin-top: 2px"><path d="m4.5 12.5 5 5 10-11"/></svg>
      <div style="font-size: 14px; line-height: 1.5; color: #9BA3AF"><strong style="color: #F2F4F7; font-weight: 700">Einweisung an jedem Gerät.</strong> Wie es eingestellt wird, als Video, direkt am Gerät.</div>
    </div>
    <div style="display: flex; gap: 12px; align-items: flex-start">
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#D4FF3F" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="flex: none; margin-top: 2px"><path d="m4.5 12.5 5 5 10-11"/></svg>
      <div style="font-size: 14px; line-height: 1.5; color: #9BA3AF"><strong style="color: #F2F4F7; font-weight: 700">Deine Einstellungen bleiben.</strong> Sitzhöhe, Gewicht und die letzten Sätze — an jedem Gerät.</div>
    </div>
    <div style="display: flex; gap: 12px; align-items: flex-start">
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#D4FF3F" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="flex: none; margin-top: 2px"><path d="m4.5 12.5 5 5 10-11"/></svg>
      <div style="font-size: 14px; line-height: 1.5; color: #9BA3AF"><strong style="color: #F2F4F7; font-weight: 700">Kurse buchen.</strong> Wochenplan, Anmeldung, Warteliste.</div>
    </div>
  </div>

  <div style="flex-grow: 1"></div>

  <!-- Die Aufforderung, und der zweite Scan als benannter naechster Schritt.
       Ohne diesen Satz muss der Nutzer die zweite Handlung erraten. -->
  <div style="flex: none; margin: 0 20px 22px; background: #14161A; border: 1px solid #2A2E36; border-radius: 16px; padding: 18px; display: flex; flex-direction: column; gap: 13px">
    <div style="font-size: 17px; font-weight: 800; letter-spacing: -.015em; line-height: 1.25">In zwei Schritten dabei</div>
    <div style="display: flex; gap: 11px; align-items: baseline">
      <span class="num" style="font-size: 13px; color: #D4FF3F; flex: none">1</span>
      <span style="font-size: 13px; line-height: 1.5; color: #9BA3AF">App laden und Konto anlegen.</span>
    </div>
    <div style="display: flex; gap: 11px; align-items: baseline">
      <span class="num" style="font-size: 13px; color: #D4FF3F; flex: none">2</span>
      <span style="font-size: 13px; line-height: 1.5; color: #9BA3AF">Diesen Aushang noch einmal scannen — damit gehörst du zu <strong style="color: #F2F4F7; font-weight: 700">Kraftwerk Nord</strong>.</span>
    </div>
    <div style="height: 54px; border-radius: 14px; background: #D4FF3F; color: #0A0B0D; font-size: 16px; font-weight: 800; display: flex; align-items: center; justify-content: center">App laden</div>
    <div style="font-size: 11px; line-height: 1.5; color: #5C636E">Zurzeit nur für iPhone.</div>
  </div>
</div>
</x-dc>
</body>
</html>
```

- [ ] **Step 4: Akzentflächen zählen**

```bash
cd docs/superpowers/design/member
grep -c "background: #D4FF3F" FallbackAushang.dc.html FallbackGeraet.dc.html
```

Erwartet: `FallbackAushang.dc.html:2` und `FallbackGeraet.dc.html:3`.

**Die beiden Zahlen unterscheiden sich mit Grund.** Beide tragen den 5 px großen Punkt der Wortmarke und die Aktion *App laden*; `FallbackGeraet` trägt zusätzlich den Play-Kreis des Einweisungsvideos, das der Aushang nicht hat. Punkt und Play-Kreis sind Marke und Bedienelement, keine zweite Hauptaktion — `FallbackGeraet` steht mit 3 schon heute so im abgestimmten Bestand.

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/design/member/FallbackGeraet.dc.html \
        docs/superpowers/design/member/FallbackAushang.dc.html
git commit -m "design: Web-Fallback fuer den Aushang, zweiter Scan benannt"
```

---

### Task 5: Member-Canvas — Artboards, Annotationen, Seeden

**Files:**
- Modify: `docs/superpowers/design/member/canvas.json`

**Interfaces:**
- Consumes: `MemberScanner.dc.html` aus Task 1, `FallbackAushang.dc.html` aus Task 4. Beide müssen existieren, sonst bricht der Seeder ab.
- Produces: `gymodo-member-app.html`, die Datei, die als Artefakt veröffentlicht wird.

- [ ] **Step 1: Die beiden neuen Artboards eintragen**

In `canvas.json`, im Array `artboards`. Der Scanner kommt hinter `MemberPasswortAendern` (Seite `zugang`, nächste freie Spalte `x = 1892`):

```json
    {
      "file": "MemberScanner.dc.html",
      "x": 1892,
      "y": 0,
      "w": 393,
      "h": 852,
      "title": "05 · Code scannen",
      "page": "zugang"
    },
```

Der Aushang-Fallback kommt hinter `FallbackInaktiv` (Seite `app`, nächste freie Spalte `x = 1419` in der Reihe `y = 9920`):

```json
    {
      "file": "FallbackAushang.dc.html",
      "x": 1419,
      "y": 9920,
      "w": 390,
      "h": 844,
      "title": "27 · Web-Fallback — Aushang"
    },
```

- [ ] **Step 2: Die Kopfannotation der Seite `zugang` austauschen**

Sie beschreibt heute vier Artboards und nennt 03 als Code-Eingabe. Beides stimmt nicht mehr. Der Eintrag `hdr-zugang` wird zu:

```json
    {
      "id": "hdr-zugang",
      "x": 0,
      "y": -280,
      "w": 2285,
      "page": "zugang",
      "text": "ZUGANG · neu\nSelbstregistrierung, Passwort und Studio-Beitritt. 03 ist der wichtigste der fünf: was ein frisch registriertes Mitglied ohne Studio sieht, ohne Tab-Leiste. Der Beitritt läuft jetzt über den Scan — Aushang am Eingang oder Aufkleber am Gerät, beides derselbe Tokenraum unter /t/<token>. Der getippte Studio-Code bleibt als zweiter Weg und gibt dafür die Akzentfläche an den Scan ab. Die Anmeldung selbst (E-Mail + Passwort) und die einmalige Adressbestätigung liegen auf der Seite „App“, Artboards 01/02."
    }
```

- [ ] **Step 3: Eine Notiz zum Kaltstart neben den Aushang-Fallback setzen**

Neu im Array `annotations`, ohne `page` (Seite `app`):

```json
    {
      "id": "note-kaltstart",
      "x": 1419,
      "y": 9640,
      "w": 390,
      "text": "Der Fall, der die Kette bricht: App fehlt, iPhone. Der Universal Link landet in Safari, weil keine App ihn beansprucht — und nach der Installation startet die App bei null. Apple leitet nichts nach. Gelöst durch einen zweiten Scan, nicht durch verzögerte Deep Links und nicht durch einen App Clip; die Abwägung steht in der Spec, Abschnitt 5. Deshalb trägt diese Seite den nächsten Schritt als Text, statt ihn erraten zu lassen."
    }
```

- [ ] **Step 4: JSON auf Gültigkeit prüfen**

```bash
cd docs/superpowers/design/member
python -c "import json,io; d=json.load(io.open('canvas.json',encoding='utf-8')); print(len(d['artboards']),'Artboards'); print(len(d['annotations']),'Annotationen')"
```

Erwartet: `33 Artboards`, `18 Annotationen` — heute stehen dort 31 und 17.

- [ ] **Step 5: Jede eingetragene Datei muss existieren**

```bash
cd docs/superpowers/design/member
python -c "import json,io,os; d=json.load(io.open('canvas.json',encoding='utf-8')); fehlt=[a['file'] for a in d['artboards'] if not os.path.exists(a['file'])]; print('fehlt:', fehlt)"
```

Erwartet: `fehlt: []`.

- [ ] **Step 6: Canvas bauen und prüfen**

```bash
cd docs/superpowers/design/member
DESIGN_SKILL=<Pfad zur design-Skill> ./seed.sh
```

Erwartet: `seed-canvas.mjs` schreibt `gymodo-member-app.html`, danach läuft `--check` ohne Befund durch. Bricht es ab, nennt es die Datei — dann Step 5 wiederholen.

- [ ] **Step 7: Commit**

```bash
git add docs/superpowers/design/member/canvas.json \
        docs/superpowers/design/member/gymodo-member-app.html
git commit -m "design: Member-Canvas auf 28 Artboards, Zugang und Kaltstart annotiert"
```

---

### Task 6: Portal — Aushang bei Tags, Studio-Code als zweiter Weg

**Files:**
- Modify: `docs/superpowers/design/portal/gen_katalog.py` (Abschnitt `Tags`, endet auf `schreibe('Tags.dc.html', portal('tags', 940, tags))`)
- Modify: `docs/superpowers/design/portal/gen_verwaltung.py` (Abschnitt `EinstellungenStudio`, endet auf `schreibe('EinstellungenStudio.dc.html', portal('einstellungen', 1300, studio))`)

**Interfaces:**
- Consumes: die Bausteine aus `docs/superpowers/design/portal/build.py`. **Deren Namen vor dem Schreiben aus der Datei ablesen** — sie unterscheiden sich von denen der Member-App, und dieser Plan erfindet sie nicht.
- Produces: `Tags.dc.html`, `EinstellungenStudio.dc.html`, danach die Portal-Canvas.

**Der Bestand löst den Kern schon.** `Tags.dc.html` hat bereits eine Karte *„Gerade angelegt — nur jetzt sichtbar"* mit dem Token im Klartext, dem Satz *„Danach ist er nicht mehr abrufbar"* und der Aktion *QR-Code drucken*. Genau das ist der Weg, den auch der Aushang gehen muss — der Klartext-Token existiert genau einmal, ein Druckbogen-Knopf an einer Listenzeile wäre nicht baubar. **Der Aushang-Abschnitt zeigt deshalb keine Codes, sondern nur Anlegedatum und Sperre.**

- [ ] **Step 1: Die Abzeichen vor den Abschnitt ziehen**

`aktiv`, `vorraetig` und `gesperrt` werden heute erst unterhalb definiert, im Abschnitt *Alle Tags*. Der neue Abschnitt steht darüber und braucht ein eigenes. Die drei Zuweisungen und die neue vierte wandern **vor** den Aushang-Abschnitt:

```python
aktiv = '<span style="%s color: #f2f4f7; border-color: #5c636e;">aktiv</span>' % BADGE
vorraetig = '<span style="%s">vorrätig</span>' % BADGE
gesperrt = '<span style="%s color: #ff5a4e; border-color: #ff5a4e;">gesperrt</span>' % BADGE
aushang_badge = '<span style="%s color: #d4ff3f; border-color: #d4ff3f;">Aushang</span>' % BADGE
```

Die alten drei Zuweisungen unterhalb werden dabei **entfernt**, nicht gedoppelt — sonst stehen dieselben Namen zweimal in der Datei.

- [ ] **Step 2: Den Abschnitt `Aushang` vor `Alle Tags` einfügen**

In `gen_katalog.py`, zwischen dem Ende der Karte *„Gerade angelegt"* (`tags += '</section>'`) und dem Beginn der Karte *„Alle Tags"*:

```python
# Der Aushang haengt am Eingang, nicht am Geraet. Er zeigt hier bewusst
# keinen Code: den Klartext-Token gibt es genau einmal, beim Anlegen, in
# der Karte darueber -- gespeichert ist nur seine Pruefsumme. Ein
# "Druckbogen"-Knopf an einer Listenzeile waere ein Versprechen, das die
# Datenbank nicht einloesen kann.
tags += '<section style="%s margin-top: 24px;">' % CARD
tags += ('<div style="%s"><h2 style="%s">Aushang</h2>'
         '<a href="#" style="%s">Aushang anlegen</a></div>' % (HEADROW, SEC_TITLE, SECONDARY))
tags += ('<div style="padding: 16px 20px; border-bottom: 1px solid #2a2e36;">'
         '<span style="%s">Wer einen Aushang scannt, wird Mitglied — ohne Code, ohne Theke. '
         'Sperren macht jeden gedruckten Bogen ungültig; danach neu anlegen und neu drucken.</span></div>'
         % NOTE)
tags += zeile('%s &nbsp; Eingang' % aushang_badge, 'Angelegt Mo., 1. September 2026',
              '<a href="#" style="%s">Sperren</a>' % DESTRUCTIVE)
tags += zeile('%s &nbsp; Umkleide' % aushang_badge, 'Angelegt Mo., 1. September 2026',
              '<a href="#" style="%s">Sperren</a>' % DESTRUCTIVE, letzte=True)
tags += '</section>'
```

- [ ] **Step 3: Die Seitenhöhe anheben**

Der neue Abschnitt kostet rund 210 px. Aus

```python
schreibe('Tags.dc.html', portal('tags', 940, tags))
```

wird

```python
schreibe('Tags.dc.html', portal('tags', 1150, tags))
```

**Bleibt der Wert bei 940, wird der Abschnitt unten abgeschnitten** — lautlos, ohne Fehlermeldung. Nach dem Lauf am gerenderten Artboard nachsehen und den Wert nachziehen, falls unten Luft fehlt oder zu viel steht.

- [ ] **Step 4: In `EinstellungenStudio` den Studio-Code zum zweiten Weg erklären**

Der Abschnitt `Studio-Code` bleibt vollständig, es ändert sich nur die Erklärzeile darunter. Aus der bestehenden Zeile über Beitritt und Trainerrechte wird:

> „Mit diesem Code treten Mitglieder eurem Studio bei, wenn sie nicht scannen können. Der übliche Weg ist der Aushang unter *Tags*. Beide machen niemanden zum Trainer."

- [ ] **Step 5: Generatoren laufen lassen**

```bash
cd docs/superpowers/design/portal
python gen_katalog.py
python gen_verwaltung.py
```

Erwartet: unter den Ausgaben `geschrieben: Tags.dc.html` und `geschrieben: EinstellungenStudio.dc.html`.

- [ ] **Step 6: Portal-Canvas bauen und prüfen**

```bash
cd docs/superpowers/design/portal
DESIGN_SKILL=<Pfad zur design-Skill> ./seed.sh
```

Erwartet: die Portal-Canvas wird geschrieben, `--check` läuft ohne Befund durch. Es kommen **keine** neuen Artboards hinzu — `canvas.json` im Portal bleibt unverändert.

- [ ] **Step 7: Commit**

```bash
git add docs/superpowers/design/portal/gen_katalog.py \
        docs/superpowers/design/portal/gen_verwaltung.py \
        docs/superpowers/design/portal/Tags.dc.html \
        docs/superpowers/design/portal/EinstellungenStudio.dc.html \
        docs/superpowers/design/portal/gymodo-trainerportal.html
git commit -m "design: Aushang bei Tags, Studio-Code als zweiter Weg"
```

*Der Dateiname der Portal-Canvas steht in `docs/superpowers/design/portal/seed.sh` hinter `--out`. Vor dem Commit dort ablesen, statt ihn zu raten.*

---

## Veröffentlichen

Beide Canvas-Dateien werden über das bestehende Artefakt aktualisiert, nicht als neue angelegt — die Adressen sind in der Spec eingetragen und in den bisherigen Plänen verlinkt:

- Member-App: `4f6035c6-7612-42ed-9791-cf0794713bdd`
- Trainerportal: `fa12ef14-ca77-4fcc-a034-886a38914984`

Vor jedem Republish die veröffentlichte Fassung lesen und die eigene Änderung darauf aufsetzen. Ein Publish ohne vorheriges Lesen wird abgewiesen.
