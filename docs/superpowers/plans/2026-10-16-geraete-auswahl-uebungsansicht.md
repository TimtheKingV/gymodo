# „Gerät wählen“ mit Übungsansicht und Muskelfilter – Plan

**Ziel:** Der Bildschirm „Gerät wählen“ (Wurzel des Training-Tabs) zeigt wahlweise die Übungen des Studios statt der Geräteliste, mit denselben Ansichten wie am Gerät (Muskel / Zuletzt) und einem Filter nach Muskelgruppe.

**Umfang:** Nur die iOS-Member-App. Aufbauend auf PR #69 (`UebungsGruppierung`).

## Entscheidungen (mit Tim abgestimmt)

- Oben ein Umschalter **Übungen | Geräte**, linksbündig, Standard **Übungen**. „Geräte“ ist die bisherige Liste, unverändert.
- „Übungen“: alle Übungen des Studios in einer Liste. Darunter **Muskel | Zuletzt**. Bei „Muskel“ eine Filterleiste **Alle** (Standard), Brust, Rücken, Schultern, Arme, Beine, Rumpf; ein Tipp blendet die anderen Gruppen aus.
- Gewählte Schalter und Filter sind in der **Akzentfarbe** (nicht Weiß), alle linksbündig.
- Tipp auf eine Übung: ein Gerät → direkt dorthin. Mehrere Geräte → beim ersten Mal „An welchem Gerät?“; danach das Gerät, an dem die Übung schon gemacht wurde (aus der Historie, ohne eigenen Speicher).
- **Änderung nach Test auf dem Gerät (Entwurf A „Ein Streifen“):** Statt zweier Schalter gibt es auf „Gerät wählen“ einen Segment-Schalter **Übungen | Geräte** in voller Breite und darunter einen einzigen Chip-Streifen **Alle · Zuletzt | Brust · Rücken · …**. Alle = nach Muskel gruppiert, Zuletzt = flache Liste, eine Gruppe = nur sie (Kopf „BRUST · 6 ÜBUNGEN“). „Muskel | Zuletzt“ bleibt nur auf der Übungsseite am Gerät und im Sheet „Weitere Übung“.
- **Zweite Änderung (Struktur):** Die Wurzel „Gerät wählen“ zeigt wieder nur die Kategorie-Kacheln, jetzt **über** „Zuletzt bei dir“. Umschalter und Filterstreifen wandern eine Ebene tiefer in die Kategorie-Ansicht (z. B. Freihantel, Geräte) und gelten dort nur für deren Übungen bzw. Geräte.
- Auf der Übungsseite am Gerät entfällt „Was machst du heute?“; dort sind die Schalter ebenfalls linksbündig und in Akzentfarbe.

## Annahmen (Claude, von Tim bestätigt durch „passt“)

1. In der Übungsansicht ist „Muskel“ vorgewählt. 2. Die Suche bleibt wie sie ist; mit Suchtext erscheinen die Treffer, die Schalter sind dann ausgeblendet. 3. Der Filter wird nicht gemerkt (immer „Alle“). 4. Wer später ein anderes Gerät will, nutzt „Weitere Übung“ am Gerät. 5. (Claude) Die Wahl Übungen/Geräte wird gemerkt, `UserDefaults`. 6. (Claude) Gesperrte Geräte zählen nicht als Gerät einer Übung. 7. (Claude) „Zuletzt“ in der Übungsansicht: dieses Training, dann Häufigkeit über alle Geräte, dann Studioreihenfolge.
8. Kategorie-Screens (Tipp auf eine Gerätekachel) bleiben unverändert, ohne Schalter.

## Aufgaben

- [ ] **1. Logik + Tests** (`Workout/UebungsAuswahl.swift`, `UebungsAuswahlTests`): Übungen aus Stationen zusammenführen, „Zuletzt“-Reihenfolge, Gerätewahl (direkt / fragen). `UebungsGruppierung.gruppieren(_:nur:)` und vorhandene Gruppen. Einstellung `Auswahlmodus`.
- [ ] **2. Bausteine:** `PillenLeiste` (Akzent, linksbündig, waagerecht scrollbar) ersetzt `UebungsAnsichtSchalter`; `UebungsAbschnitte` bekommt `gruppiert` und `filter`.
- [ ] **3. Übungsseite am Gerät:** Text raus, Schalter linksbündig in Akzent (`GeraetErkanntView`, `UebungWechselnSheet`).
- [ ] **4. „Gerät wählen“:** Umschalter, Übungsliste, Filterleiste, Geräterückfrage (`GeraeteAuswahlView`).
- [ ] **5. Prüfen:** Tests, Build aufs iPhone, PR, nach grüner CI mergen.

## Review-Fokus

- Übung an mehreren Geräten erscheint nur einmal; Tipp ohne Historie fragt, mit Historie nicht.
- Übung nur an gesperrten Geräten erscheint nicht.
- Gewählter Filter, dessen Gruppe es nicht mehr gibt → verhält sich wie „Alle“.
- Leerer Zustand ohne Geräte/Katalog bleibt wie bisher.

## Dritte Änderung (nach Test auf dem Gerät) – gilt vor allem Obigen

- **Übungsliste auf „Gerät wählen“ entfällt**, ebenso der Schalter Übungen|Geräte. In **jeder** Kategorie zeigt die Seite nur Geräte, mit dem großen Schalter **Muskeln | Favoriten** (Muskeln vorgewählt, nicht gemerkt) und darunter den Bullets **Alle · Brust · … · Vielseitig** (ohne „Zuletzt“).
- **Favoriten:** nur Geräte, an denen schon trainiert wurde, das jüngste zuerst.
- **Muskeln:** Ein Gerät gehört zu den Hauptgruppen all seiner Übungen. In „Alle“ steht es genau einmal: bei seiner einzigen Gruppe, sonst unter **Vielseitig** (ganz unten). Filtert man ausdrücklich nach einer Gruppe, erscheint es dort trotzdem, auch ein vielseitiges Gerät.
- **Übungsseite eines Geräts:** großer Schalter **Muskelgruppe | Favorit** (Muskelgruppe vorgewählt, gemerkt) und Bullets ohne „Zuletzt“. Favorit zeigt nur Übungen mit Historie. Bis 5 Übungen ohne Schalter.
- **Übungskarten:** Die Zeile „vor 2 Tagen · 73,0 kg“ steht in Akzentfarbe, wie bei den Geräten.
- Meine Entscheidungen dazu: „Weitere“ (Geräte ganz ohne Muskeldaten, z. B. Cardio) steht vor „Vielseitig“; die Favoriten der Geräte sind nach letztem Satz sortiert, die der Übungen nach der Geräte-Reihenfolge (dieses Training, Häufigkeit).
