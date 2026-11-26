# Follow-along-Flows – Entwurf

Stand: 26.11.2026 · Status: **Entwurf, noch nicht abgestimmt** · App: `apps/ios-member` (SwiftUI), Daten: Supabase, Import: `tools/`

## Absicht und Warum

Tim will nicht selbst überlegen, welche Übungen in welcher Reihenfolge ein gutes Training ergeben. Auf YouTube gibt es dafür erprobte Kurse. Die Idee: den Ablauf eines beliebten Kurses herauslesen, daraus einen **eigenen** Flow bauen und diesen in der App als geführtes Training anbieten, verbunden mit Tracking.

Der Probelauf mit dem Video „20 Minuten Ganzkörper HIIT-Workout" (Sascha Huber, 1,4 Mio. Aufrufe, 43 000 Likes, `dS4uUM5UfOA`) hat gezeigt: Der Ablauf lässt sich aus dem Transkript sauber herauslesen (20 Intervalle, 40 s Arbeit, 20 s Pause, davon 3 Warm-up). Der Katalog der App kennt aber keine Körpergewichtsübungen und ist zeitlos auf Geräte und Wiederholungen ausgelegt.

## Ziele

- Ein **Follow-along-Flow** ist eine feste Folge von Schritten mit je Arbeitszeit und Pause, die die App per Timer führt.
- Flows entstehen aus einem **Importweg** (Video → Transkript → Auswertung → Entwurf → Prüfung durch Tim), nicht von Hand.
- Die App zeigt Übungsname, eigene Kurzbeschreibung, Restzeit und die **nächste** Übung.
- Gespeichert wird, **ob und wie weit** ein Flow absolviert wurde. Das ist die Grundlage für ein eigenes „Kundenfeedback" (z. B. wo Leute abbrechen).
- Der Gerätekatalog und das Planmodell bleiben unangetastet.

## Nicht-Ziele

- Keine Aufnahme der Körpergewichtsübungen in den Hauptkatalog (Weg b, später möglich).
- Keine Einbettung oder Wiedergabe der YouTube-Videos in der App.
- Keine Wiederholungszählung und keine Sensorik in der ersten Version.
- Keine Verknüpfung mit dem Trainingsplan oder dem Wochenraster.
- Kein Trainerportal zum Anlegen von Flows in der ersten Version. Flows kommen aus dem Importskript.

## Anti-Ziele

- Wir übernehmen **keine Texte, Namen, Bilder oder Videos** des Trainers. Beschreibungen sind eigene, kurze Formulierungen. Übernommen wird nur die abstrakte Struktur (welche Übung, wie lange, in welcher Reihenfolge).
- Der Importweg darf nichts in die Produktion schreiben, ohne dass Tim den Entwurf gesehen hat.
- Ein Flow darf nicht so aussehen, als stamme er vom Trainer oder werde von ihm empfohlen.

## Ansätze

1. **Eigenes Format „Follow-along" (gewählt, Tim am 26.11.).** Flow bringt eine eigene schlanke Übungsliste mit. Schnell, bricht nichts am Katalog, passt zu Zeitintervallen.
2. **Körpergewichtsübungen in den Hauptkatalog.** Sauberer und später kombinierbar mit Plänen, aber viel Arbeit (Beschreibungen, Muskeln, Videos) und passt schlecht zu Zeitintervallen statt Wiederholungen. Bewusst vertagt.
3. **Nur Verweis auf das YouTube-Video.** Kein eigener Flow, kein Tracking, widerspricht dem Ziel.

## Datenmodell (meine Annahme, vom Bauenden zu prüfen)

- `flows`: `id`, `studio_id`, stabiler `key`, Titel, Kurzbeschreibung, Level, Quelle (`source_url`, `source_channel`, nur als Herkunftsnachweis), `created_at`. Die Gesamtdauer wird aus den Schritten berechnet und nicht gespeichert (Stand 26.11., Plan).
- `flow_steps`: `flow_id`, Position, Name, eigene Beschreibung, `work_s`, `rest_s`, `is_warmup`.
- `flow_runs`: `id` (clientseitig erzeugt, wie `workout_sessions`), `flow_id`, `user_id`, `studio_id`, `started_at`, `completed_at`, `last_step`, `completed_reason` (`finished` / `aborted`).
- RLS wie bei den bestehenden Tabellen: Mitglieder des Studios lesen Flows, Schreiben von `flow_runs` nur durch das Mitglied selbst, Flows nur über das Importskript beziehungsweise Service-Zugriff.
- Studio-weit statt global, damit es zum übrigen Modell passt (**meine Annahme**, siehe offene Fragen).
- **Gymtavo-Katalog (Stand 26.11., Migration 0079):** Ein Flow im Katalog-Studio (`is_catalog`, feste id `00000000-0000-4000-8000-000000000001`) ist für jeden Angemeldeten lesbar, auch ohne Studio, wie Geräte und Übungen (Spec `2026-10-06-gymtavo-katalog-offener-zugang-design.md`, 5.2). Ein Lauf eines Katalog-Flows trägt das Katalog-Studio als `studio_id`. Geschrieben werden Flows weiterhin nur per Service-Zugriff. Ein einziger Seed gilt damit für alle Studios.

## Importweg

```
tools/flow-import/
  YouTube-Link
    → yt-dlp: Untertitel (de), bei Lücken Frames per ffmpeg
    → Claude: Schritte, Zeiten, Pausen, Warm-up erkennen
    → flow.json (Entwurf) + Liste unsicherer Schritte
    → Tim prüft
    → Seed/Migration
```

- Auto-Untertitel zerlegen Übungsnamen. Unsichere Schritte werden markiert und mit Frames geklärt (im Probelauf: Schritte 4, 11 und 15 waren nur so zu klären; 4 und 11 bleiben „mittel sicher").
- Das Intervall-Overlay im Video („Round 7") hilft, die Zählung zu verifizieren.

## Ablauf in der App

1. **Flow-Detail:** Titel, Dauer, Liste der Übungen, „Starten".
2. **Countdown:** 3-2-1.
3. **Arbeitsphase:** Übungsname, Restzeit (Ring), „Als Nächstes: …", Haptik beim Wechsel.
4. **Pause:** Restzeit, nächste Übung groß.
5. **Fertig:** Dauer, absolvierte Schritte.

Bildschirm bleibt während des Flows an. Pause und Abbrechen sind jederzeit möglich; Abbrechen speichert `aborted` mit letztem Schritt. Der Flow wird vor dem Start lokal geladen, damit er offline läuft (Muster aus `2026-10-15-offline-stabilitaet-design.md`).

## Erster Testflow

„HIIT 20 Min": 3 Warm-up (High Kicks, Slow Burpees, Jumping Jacks) und 17 Intervalle (Toe Touches + Jackknifes, Mini Scissor Kicks, Burpees mit Oberschenkel-Berührung, Squat-Pulse, Plank, Swimmer, Russian Twist, Lunge + Kick, Liegestütze, Leg Drop & Pull, Weitsprung mit Bodenberührung, Squat mit Händen zum Boden, Plank mit Knie zur Brust, Flutter Kicks, Skater Jumps, Crunch-Halten, Burpees mit Streckung), jeweils 40 s Arbeit und 20 s Pause.

## Offene Fragen (Tim)

1. **Wohin in der App?** Eigener Bereich im Training-Tab oder bei den Kursen?
2. **Gilt ein Flow pro Studio oder für alle?**
3. **Namen und Quelle:** Soll die Quelle in der App sichtbar sein („Inspiriert von …") oder nur intern gespeichert werden? Vor einem Live-Gang sollte der rechtliche Umgang mit der Quelle geklärt sein.
4. **Ton:** Sprachansagen der nächsten Übung in Version 1 oder später?

## Was dem Bauenden bleibt

Genaue Tabellen- und Spaltennamen, Screens und Texte, Format der `flow.json`, Aufteilung in Etappen.
