#!/usr/bin/env python3
"""Testprofile fuer den Debug-Build der Member-App.

Liest data/koerperbild/zuordnung.json, data/koerperbild/flow-zuordnung.json und
catalog/gymtavo.json und schreibt
apps/ios-member/FitnessMember/Resources/KameraTestprofile.json: je Uebung mit
Profil ganzkoerper_stehend oder oberkoerper Name, Schluessel, Kamera und Tempo,
sortiert nach Schluessel. Die Eintraege der Flow-Zuordnung (Kamera-Schritte der
Follow-along-Flows) kommen unabhaengig vom Profil hinzu und ersetzen einen
gleichen Schluessel aus dem Zuordnungsvorschlag; sie tragen "flow": true, damit
der Flow sie bei gleichem Namen vorzieht. Nur Standardbibliothek; aus der Repo-Wurzel starten:

    python3 tools/kamera-zuordnung/testprofile.py

Katalog und Freischaltung bleiben unberuehrt; die App liest die Datei nur im
Debug-Build.
"""
import json
from pathlib import Path

WURZEL = Path(__file__).resolve().parents[2]
KATALOG = WURZEL / "catalog" / "gymtavo.json"
ZUORDNUNG = WURZEL / "data" / "koerperbild" / "zuordnung.json"
FLOW_ZUORDNUNG = WURZEL / "data" / "koerperbild" / "flow-zuordnung.json"
AUSGABE = WURZEL / "apps" / "ios-member" / "FitnessMember" / "Resources" / "KameraTestprofile.json"

PROFILE = {"ganzkoerper_stehend", "oberkoerper"}


def main() -> None:
    namen = {e["key"]: e["name"] for e in json.loads(KATALOG.read_text("utf-8"))["exercises"]}
    zuordnung = json.loads(ZUORDNUNG.read_text("utf-8"))
    gewaehlt = {key: z for key, z in zuordnung.items() if z["kamera"]["profil"] in PROFILE}
    flow = json.loads(FLOW_ZUORDNUNG.read_text("utf-8"))
    gewaehlt.update(flow)
    eintraege = []
    for key in sorted(gewaehlt):
        z = gewaehlt[key]
        eintrag = {"name": namen[key], "key": key, "kamera": z["kamera"], "tempo": z["tempo"]}
        if key in flow:
            # Kennzeichen: im Flow gewinnt dieser Eintrag bei gleichem Namen.
            eintrag["flow"] = True
        eintraege.append(eintrag)
    AUSGABE.write_text(json.dumps(eintraege, ensure_ascii=False, indent=2) + "\n", "utf-8")
    print(f"{len(eintraege)} Testprofile -> {AUSGABE.relative_to(WURZEL)}")


if __name__ == "__main__":
    main()
