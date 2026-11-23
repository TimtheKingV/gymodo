# Weitere Übungen mit Körpergewicht – Vorschlagsliste

Stand 23.11.2026. Vorschläge von Claude. Tim hat alle 31 gewählt; 30 stehen in
`catalog/gymtavo.json`, Nr. 28 ist zurückgestellt (siehe unten). Alle Übungen hängen am
vorhandenen Typ `bodyweight` (Etikett `Körpergewicht`), Schlüssel mit `bw_`. Namen folgen
`docs/katalog-stilleitfaden.md`.

Schon im Katalog (18): Plank, Seitstütz, Crunch, Beinheben – liegend, Dead Bug, Bird Dog,
Rückenstrecken – liegend, Hollow Hold, Mountain Climber, Liegestütz, Liegestütz – erhöht,
Liegestütz – kniend, Kniebeuge, Ausfallschritt – rückwärts, Glute Bridge, Glute Bridge – einbeinig,
Wandsitzen, Hüftabduktion – Seitlage.

Kürzel: **E** = leichter als die vorhandene Grundübung, **F** = schwerer, **Sek** = Halteübung in
Sekunden (ohne Plan-Merkmale), **Bank** = braucht eine Bank oder Stufe wie „Liegestütz – erhöht“.

## Vorschläge (31)

**Rumpf**

1. Plank – kniend (E, Sek)
2. Plank – Schultertippen (F) – im hohen Stütz abwechselnd eine Hand zur Gegenschulter, Becken bleibt ruhig
3. Seitstütz – kniend (E, Sek)
4. Seitstütz – Hüftheben – Hüfte im Seitstütz absenken und anheben, seitlicher Rumpf mit Wiederholungen
5. Russian Twist – rotierend, ohne Gewicht
6. Bicycle Crunch – rotierend, Ellenbogen zum Gegenknie
7. Reverse Crunch – Becken einrollen, leichter als Beinheben – liegend
8. Klappmesser (F) – Arme und Beine gestreckt zusammenführen

**Drücken**

9. Liegestütz – eng – Hände schulterbreit, Ellenbogen am Körper, mehr Trizeps
10. Liegestütz – Füße erhöht (F, Bank)
11. Pike Push-up (F) – Hüfte hoch, Kopf zwischen die Hände senken, Schulterdrücken ohne Gerät
12. Dips – Bank (Bank) – Hände hinter dem Körper auf der Bankkante

**Ziehen**

Ohne Gerät gibt es keine Zugübung mit echtem Widerstand; die beiden hier sind leichte
Aktivierungsübungen für Latissimus und oberen Rücken.

13. Latzug – Bauchlage – Arme aus der Vorhalte zu den Rippen ziehen, Brust leicht angehoben
14. Rudern – Bauchlage – Ellenbogen nach hinten oben ziehen, Schulterblätter zusammen

**Beine – Knie**

15. Kniebeuge – auf Bank absetzen (E, Bank)
16. Kniebeuge – einbeinig (F, Bank) – einbeinig auf die Bank absetzen und aufstehen
17. Ausfallschritt – vorwärts
18. Ausfallschritt – seitlich
19. Bulgarian Split Squat (F, Bank)
20. Step-up (Bank)

**Beine – Hüfte**

21. Hip Thrust (Bank) – Schultern auf der Bank, größerer Weg als die Glute Bridge
22. Glute Bridge – Fersen weit vorn – Füße weiter weg vom Gesäß, mehr Beinbeuger
23. Rumänisches Kreuzheben – einbeinig – ohne Gewicht, Gleichgewicht und Hüftbeuge

**Beine – Ergänzung**

24. Wadenheben – stehend
25. Wadenheben – einbeinig (F)
26. Hüftadduktion – Seitlage – unteres Bein anheben
27. Clamshell – Seitlage, Knie gebeugt, oberes Knie aufklappen
28. Schienbeinheben – an der Wand – Rücken an der Wand, Fußspitzen anheben (Schienbeinmuskel hat bisher keine Hauptübung)

**Schulter**

29. Y-Heben – Bauchlage – gestreckte Arme in Y-Form anheben
30. Reverse Flys – Bauchlage – Arme seitlich anheben, hintere Schulter
31. Schulterblatt-Liegestütz – im Stütz nur die Schulterblätter bewegen (Sägemuskel hat bisher keine Hauptübung)

## Zurückgestellt: Nr. 28 Schienbeinheben

Der Schienbeinmuskel (`tibialis`) steht in der iOS-App auf der Liste
`Ausgewogenheit.ohneKraftuebung` und bleibt deshalb grau, ohne Hinweis. Ein Vertragstest in
`gymtavo-katalog.test.ts` verlangt, dass er von der Liste verschwindet, sobald eine Kraftübung ihn
trainiert. Dann bewertet die App ihn bei allen Mitgliedern: Wer kein Schienbeinheben macht, sieht
„Nachholbedarf“ und den Hinweis „kam in 28 Tagen nicht dran“. Das ist eine eigene Entscheidung
(Swift-Liste und drei Swift-Tests ändern, App neu bauen) und nicht Teil dieser Katalogerweiterung.
Aus demselben Grund führen die beiden Wadenheben-Übungen den Wadenbeinmuskel nicht als Nebenmuskel.

## Reserve

Bewusst weggelassen, auf Zuruf schnell ergänzt: Liegestütz – breit, Sumo-Kniebeuge,
Ausfallschritt – gehend, Kniebeuge – gesprungen, Hip Thrust – einbeinig, Good Morning,
Hüftstrecken – Vierfüßlerstand, Hüftabduktion – Vierfüßlerstand, Flutter Kicks (Sek),
Scheibenwischer, Rückenstrecken – Schwimmer, Wall Slide.

## Bräuchte neuen Gerätetyp

Gehören nicht unter `bodyweight`, weil ein Gerät nötig ist.

| Gerätetyp | Übungen |
|---|---|
| Klimmzugstange (frei, ohne Unterstützung) | Klimmzug, Klimmzug – Untergriff, Hängen (Sek). Unterstützte Klimmzüge und Dips gibt es schon am `Klimmzug-/Dip-Gerät`. |
| Dip-Barren (frei) | Dips, Stütz halten (Sek) |
| Schlingentrainer | Rudern, Liegestütz, Face Pull, Pike, Beincurl |
| Tiefe Stange / Multipresse | Rudern – Rückenlage (Inverted Row), die beste Zugübung mit Körpergewicht |
| Bauchroller | Ab Rollout |
| Fußfixierung (Sprossenwand, Partner) | Nordic Curl, Sit-up |
| Plyo-Box | Box Jump |
| Gleitscheiben / Handtuch | Beincurl – rutschend, Ausfallschritt – rutschend |
