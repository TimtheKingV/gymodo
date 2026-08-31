# Kurse — Datenmodell und Backend (Vorabnotiz, noch nicht begonnen)

**Stand:** 30. August 2026
**Status:** **nicht begonnen.** Nur Design existiert (Artboards 18–20 der Design-Canvas). Keine Migration, kein Endpoint, keine Zeile Code.
**Warum es dieses Dokument gibt:** Der Kurse-Tab wurde am 30.08. ins Frontend-Design aufgenommen. Das Design läuft dem Backend damit voraus. Diese Notiz hält fest, was fehlt, damit die Lücke sichtbar bleibt statt vergessen zu werden.

---

## Was entschieden wurde

Die Member-App bekommt einen **vierten Tab „Kurse"** zwischen Training und Profil, mit Kalender-Icon. Mitglieder sehen den Kursplan ihres Studios und melden sich an.

Begründung: Kursbetrieb hat praktisch jedes Studio. Er ist damit kein Zusatzfeature, sondern etwas, das ein Betreiber im Pitch erwartet — und ein Grund, die App auch an Tagen zu öffnen, an denen niemand an ein Gerät tappt.

## Was das an der M1-Spec ändert

`docs/superpowers/specs/2026-08-28-fitness-retrofit-m1-design.md` führt Kurse in **§5.1 als reservierten fünften Tab** („Reserviert, nicht gebaut") und schließt sie in **§4.2** aus dem Umfang aus. Diese Notiz widerspricht dem bewusst und teilweise:

- Der Tab rückt von Position 5 auf **Position 4**; `Plan` (M3) bleibt der einzige reservierte.
- Der Umfang von **M1 bleibt unverändert**. Kurse werden nicht in M1 gebaut.

Wann sie gebaut werden, ist offen. Sinnvoll ist **M2** (Betreiber-Pitch-Paket) — dort zahlt der Kursplan direkt auf das Verkaufsargument ein, und die Trainer-Weboberfläche, die den Kursplan pflegen muss, entsteht dort ohnehin.

---

## Was fehlt — Tabellen

Alle mit `studio_id`, `ENABLE` **und** `FORCE ROW LEVEL SECURITY`, Positiv-, Negativ- und Cross-Tenant-Test je Policy. Das ist nicht verhandelbar (Spec §10).

```text
course_templates    studio_id, name, description, default_duration_min,
                    default_capacity, photo_path
course_sessions     studio_id, course_template_id, starts_at timestamptz,
                    duration_min, capacity, room, instructor_user_id,
                    status ∈ {geplant, abgesagt}
course_bookings     studio_id, course_session_id, user_id,
                    status ∈ {gebucht, warteliste, storniert},
                    waitlist_position int?, booked_at, cancelled_at
                    unique (course_session_id, user_id) partial where status <> 'storniert'
```

Bewusste Entscheidungen, die in dieser Struktur schon stecken:

- **Vorlage und Termin getrennt.** „Kraftzirkel" ist die Vorlage, „Do 27.08. 18:00" der Termin. Ohne diese Trennung pflegt ein Trainer jede Woche dieselbe Beschreibung neu.
- **`capacity` liegt am Termin, nicht an der Vorlage.** Ein Kurs im kleinen Raum hat weniger Plätze als derselbe Kurs im großen.
- **Kein Recurrence-Feld in der ersten Fassung.** Serientermine werden beim Anlegen im Trainerportal *materialisiert* — echte Zeilen, keine Regel. Eine Wiederholungsregel, die man später auflösen muss, ist der klassische Kalender-Sumpf; sie kommt erst, wenn ein Studio sie wirklich braucht.
- **Absage statt Löschen.** `status = 'abgesagt'` bleibt stehen, damit angemeldete Mitglieder sehen, was passiert ist. Ein gelöschter Termin sieht aus wie ein Fehler in der App.
- **Warteliste ist ein Zustand der Buchung, keine zweite Tabelle.** Das hält das Nachrücken zu einem `UPDATE`.

## Was fehlt — Fachlogik

Das eigentliche Risiko liegt nicht im Schema, sondern hier:

1. **Platzvergabe unter Nebenläufigkeit.** Zwei Mitglieder tippen gleichzeitig auf „Anmelden", ein Platz ist frei. Das muss serverseitig in einer Transaktion entschieden werden (`select … for update` auf den Termin oder ein Constraint über die Belegungszahl) — **niemals** durch Zählen im Client. Das ist die einzige Stelle im ganzen Produkt mit echtem Wettlauf.
2. **Nachrücken.** Storniert jemand, rückt die Warteliste auf. Synchron im selben Request lösbar, solange die Liste kurz ist — das hält die Regel „kein Async in M1/M2" (Spec §6.7).
3. **Benachrichtigung beim Nachrücken.** Das Design verspricht auf Artboard 20 „und eine Nachricht". Push gibt es nicht (Spec §4.2), E-Mail bräuchte den SMTP-Fix, der ohnehin für den OTP-Login aussteht. **Bis das geklärt ist, darf dieser Satz nicht in die App.** Entweder Push/E-Mail bauen oder den Text ändern.
4. **Stornofrist.** Das Design nennt zwei Stunden vor Beginn. Das ist eine Studioregel, keine Plattformregel — gehört als Feld ans Studio oder an die Vorlage, nicht als Konstante in den Code.
5. **Zeitzone.** Termine sind `timestamptz`, angezeigt in `studios.timezone`. Bei Kursen fällt eine Sommerzeitumstellung sofort auf; bei Trainingssätzen nicht.

## Was fehlt — Schnittstelle und Oberfläche

- **Member-App (HTTP, screenorientiert wie Spec §6.3):**
  `GET /api/v1/me/courses?from=&to=` (Wochenplan inkl. eigenem Buchungsstatus und freien Plätzen),
  `PUT /api/v1/course-sessions/{id}/booking` (anmelden, clientgenerierte UUID → strukturell idempotent),
  `DELETE /api/v1/course-sessions/{id}/booking` (abmelden).
- **Trainerportal (Server Actions, kein HTTP):** Vorlagen pflegen, Termine anlegen und absagen, Teilnehmerliste einsehen, Serie materialisieren.
- **RLS:** Mitglieder lesen die Termine ihres Studios und ausschließlich **eigene** Buchungen. Trainer und Owner sehen die Teilnehmerlisten. Schreiben auf `course_templates`/`course_sessions` nur `trainer`/`owner`.
- **Datenschutz:** Die Teilnehmerliste ist für andere Mitglieder **nicht** sichtbar. Wer wann im Kurs war, ist eine Anwesenheitsliste — die gehört dem Studio, nicht der Mitgliedschaft.

---

## Reihenfolge, wenn es losgeht

1. Migration `course_templates`, `course_sessions`, `course_bookings` mit RLS und vollständiger Testmatrix.
2. Nebenläufigkeitstest für die Platzvergabe **vor** jeder Oberfläche — parallele Anmeldungen auf den letzten Platz, genau eine gewinnt.
3. Trainerportal: Vorlagen und Termine, sonst gibt es nichts anzuzeigen.
4. `GET /me/courses`, dann Buchen und Stornieren.
5. Nachrücken plus die Entscheidung aus Punkt 3 oben (Benachrichtigung oder ehrlicherer Text).

## Offen

- Zeitpunkt: M2 oder später.
- Benachrichtigung beim Nachrücken — bis dahin darf das Design nichts versprechen.
- Ob Kursteilnahmen im Trainingsverlauf des Mitglieds auftauchen (Home-Tab) oder getrennt bleiben. Getrennt ist die ehrlichere Variante: die Plattform weiß nicht, ob jemand wirklich da war — sie kennt nur die Anmeldung.
