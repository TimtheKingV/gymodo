"""Traegt Aufnahmen eines Tages in data/sensoraufnahmen/korrekturen.json ein.

Aufruf: python3 -I eintragen.py 2026-10-18 saetze-2026-10-18.csv

Die Wahrheit kommt aus der CSV (Spalte reps_wahr), zugeordnet ueber set_id =
kontext.setId in aufnahme.json. Nur gesicherte Saetze mit Wahrheit zaehlen
(fuerZaehler true); alles andere bleibt mit Grund eingetragen, aber false.
Bestehende Eintraege bleiben unveraendert.
"""
import csv
import glob
import json
import os
import sys

WURZEL = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'data', 'sensoraufnahmen')

SONDERFAELLE = {
    '2026-10-18-1702-01': 'in der App als Langhantelrudern Satz 3 gefuehrt, laut Testnotiz 18.10. High-Bar-Kniebeuge Satz 3',
}


def main(tag, csv_name):
    pfad = os.path.join(WURZEL, 'korrekturen.json')
    with open(pfad, encoding='utf-8') as f:
        daten = json.load(f)
    wahr = {}
    with open(os.path.join(WURZEL, csv_name), encoding='utf-8') as f:
        for z in csv.DictReader(f):
            wahr[z['set_id'].upper()] = int(z['reps_wahr'])
    for ordner in sorted(glob.glob(os.path.join(WURZEL, tag + '-*'))):
        name = os.path.basename(ordner)
        if name in daten['aufnahmen'] or not os.path.exists(os.path.join(ordner, 'messwerte.csv')):
            continue
        with open(os.path.join(ordner, 'aufnahme.json'), encoding='utf-8') as f:
            a = json.load(f)
        k = a['kontext']
        set_id = (k.get('setId') or '').upper()
        art = a.get('befestigungsart')
        eintrag = {
            'was': k.get('exerciseName') or 'unbekannt',
            'befestigung': a.get('befestigung'),
            'befestigungsart': art,
            'repsWahr': wahr.get(set_id),
            'fuerZaehler': False,
            'grund': None,
        }
        if a['abschluss'] != 'gesichert' or set_id not in wahr or art is None:
            eintrag['repsWahr'] = None
            eintrag['grund'] = 'abgebrochen, kein Satz'
        else:
            eintrag['fuerZaehler'] = True
            eintrag['grund'] = SONDERFAELLE.get(name)
        daten['aufnahmen'][name] = eintrag
    with open(pfad, 'w', encoding='utf-8') as f:
        json.dump(daten, f, ensure_ascii=False, indent=2)
        f.write('\n')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
