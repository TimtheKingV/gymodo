# GYMTAVO – Muskelkarten, Revision 4

## Inhalt
- assets/: vier editierbare SVGs (männlich/weiblich, vorne/hinten).
- Nicht enthalten: Muskelmodell-Bizepspose.png, Waden-Korrektur.png und beispiel-muskelzuordnung.json aus dem Lieferumfang der Revision 4.

## Änderungen
Angehobene Hände wieder geöffnet. Sichtbare Trizeps- und Unterschenkelanteile vorne sowie Adduktoren, Rotatorenmanschette und seitliche Rumpfanteile hinten separat zugeordnet. Große unbeabsichtigte zentrale Rückenlücke geschlossen.

Bestehende Muskel-IDs bleiben erhalten. Ergänzte Pfade tragen data-visible-portion="true". Bestehende Gruppen triceps, calves, adductors und obliques werden ansichtsübergreifend angesprochen. Neu hinzugefügte Gruppen fibularis und rotator_cuff müssen bei einer App-Integration auch im Muskelkatalog geführt werden. Nicht jede anatomische Detailfläche ist ein Muskel: Gelenke, Sehnen, Hände, Füße und Kopf bleiben neutral.

## Darstellung
Alle Pfade mit passendem data-muscle in beiden Ansichten gemeinsam markieren. Die Farben der App sind in docs/superpowers/specs/2026-08-30-designsystem.md §13.1 festgelegt (die ursprüngliche grüne Palette der Lieferung gilt nicht). Der Verlauf ist ein Gestaltungsmerkmal und stellt keine räumlich gemessene Aktivierungsverteilung dar. Eine sanfte Deckkraftanimation hebt die Auswahl hervor; keine tatsächliche Muskelkontraktion oder EMG-Messung.

Beispielrollen entsprechen dem vorhandenen Übungskatalog und bleiben schematisch. Das Modell zeigt zur Funktionsdarstellung teilweise freigelegte tiefere Muskelgruppen und ist keine schichtgetreue anatomische Präparation. Insbesondere der Rücken enthält real auch Faszien und Sehnenflächen; eine helle Fläche ist nicht automatisch fehlende Muskulatur. Fachliche Freigabe weiterhin offen.

## Prüfung
Vier SVGs erfolgreich gerendert und visuell geprüft. XML und Pfade gültig; alle bisherigen Muskel-IDs erhalten, ergänzte IDs eindeutig. Interaktionslogik der Vorschau für zwölf Kombinationen aus Übung und Modell sowie Pausenfunktion geprüft. Browser-Rendering konnte wegen eines fehlgeschlagenen Browser-Downloads nicht zusätzlich geprüft werden.

## Anatomische Referenzen
https://openstax.org/books/anatomy-and-physiology/pages/11-5-muscles-of-the-pectoral-girdle-and-upper-limbs
https://pmc.ncbi.nlm.nih.gov/articles/PMC3512278/

MIT-Lizenz der ursprünglichen Vektorbasis: siehe LICENSE.txt.

## Revision 4: Wadenkonturen
Nur Wadenpfade in beiden Rückansichten geändert. Zwei abgerundete Wadenköpfe mit versetzten, spitz auslaufenden Enden statt waagerechter Trennung. Sichtbare Soleus-Anteile seitlich auslaufend, Kniekehle freigestellt. Die Darstellung bleibt schematisch. Alle Muskel-IDs und data-muscle-Zuordnungen unverändert; vorhandene Aktivierungslogik kann weiter genutzt werden. Vorderansichten und übrige Muskelpfade unverändert. Vier Gesamtansichten und beide Wadenvergleiche gerendert und visuell geprüft.
