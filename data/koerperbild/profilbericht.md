# Profilbericht Stufe 1 (Kamera)

Erzeugt von ProfilBerichtTests aus data/koerperbild/skelette und data/koerperbild/zuordnung.json.

Jedes Video wird sechsmal hintereinander abgespielt (1 s Ruhe mit dem ersten Bild davor, dann `los`), ohne gemerkten Hub. Richtig gezaehlt: 5 oder 6 Wiederholungen. Pflichtgelenk-Anteil: Anteil der Bilder, in denen alle Pflichtgelenke der fuehrenden Seite sicher sind (fuehrende Seite am Ende des Laufs, ohne Zaehlung links). Bestanden: mindestens 90 % richtig und Median des Pflichtgelenk-Anteils mindestens 95 %.

| Profil | Videos | richtig gezaehlt | Anteil | Median Pflichtgelenke | Stufe 1 bestanden |
|---|---|---|---|---|---|
| ganzkoerper_stehend | 22 | 20 | 90.9 % | 100.0 % | ja |
| liegend | 22 | 22 | 100.0 % | 94.7 % | nein |
| oberkoerper | 85 | 84 | 98.8 % | 100.0 % | ja |
| stuetz_boden | 3 | 3 | 100.0 % | 100.0 % | ja |
| zug_haengend | 10 | 10 | 100.0 % | 98.8 % | ja |

## ganzkoerper_stehend: nicht richtig gezaehlt (2)

| Video | Signal | gezaehlt / erwartet | Pflichtgelenke | fuehrende Seite | Hub |
|---|---|---|---|---|---|
| bb_reverse_lunge | knie | 12 / 5 oder 6 | 100.0 % | rechts | 45.2 Grad |
| bw_reverse_lunge | knie | 18 / 5 oder 6 | 100.0 % | rechts | 39.9 Grad |

## liegend: nicht richtig gezaehlt (0)

keine

## oberkoerper: nicht richtig gezaehlt (1)

| Video | Signal | gezaehlt / erwartet | Pflichtgelenke | fuehrende Seite | Hub |
|---|---|---|---|---|---|
| cable_shrug | ellbogen | 17 / 5 oder 6 | 100.0 % | rechts | 27.6 Grad |

## stuetz_boden: nicht richtig gezaehlt (0)

keine

## zug_haengend: nicht richtig gezaehlt (0)

keine

## Ohne Video

keine
