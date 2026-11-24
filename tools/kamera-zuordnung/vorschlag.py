#!/usr/bin/env python3
"""Zuordnungsvorschlag Kameraprofil, Signal, "beginnt mit" und Tempo je Uebung.

Liest catalog/gymtavo.json und die Kopie des Versuchs
(data/koerperbild/versuch-2026-11-23.csv), schreibt
data/koerperbild/zuordnung.json und docs/kamera-zuordnung-2026-11.md.
Nur Standardbibliothek; aus der Repo-Wurzel starten:

    python3 tools/kamera-zuordnung/vorschlag.py

Die Ausgabe ist ein Vorschlag fuer Tim, kein Katalogeintrag.
"""
import csv
import json
import re
from collections import Counter, OrderedDict
from pathlib import Path

WURZEL = Path(__file__).resolve().parents[2]
KATALOG = WURZEL / "catalog" / "gymtavo.json"
VERSUCH = WURZEL / "data" / "koerperbild" / "versuch-2026-11-23.csv"
AUSGABE_JSON = WURZEL / "data" / "koerperbild" / "zuordnung.json"
AUSGABE_MD = WURZEL / "docs" / "kamera-zuordnung-2026-11.md"

# --- Schluesselmuster (Regex auf Schluessel bzw. Namen, klein geschrieben) ---------------

WECHSEL_NAME = re.compile(r"abwechselnd|im wechsel|alternierend")

# Regel 4
STUETZ_MUSTER = re.compile(r"stütz|push|dip")
HAENGEND_MUSTER = re.compile(r"hanging|pullup|chinup|lat_pulldown|klimmzug|latzug|hängend")
LIEGEND_MUSTER = re.compile(r"bank|crunch|beinheben|liegend|seitlage|bridge|hip_thrust|bench|lying")
# Kabelzug und Geraete sind selten liegend: dort nur, wenn wirklich auf der Bank gelegen wird.
LIEGEND_MUSTER_STRENG = re.compile(r"bank|bench|liegend|lying")
LIEGEND_GRUPPEN = {"freihantel", "eigengewicht", "kettlebell", "gummiband", "cardio"}

# Uebungen, deren Signal Knie oder Huefte sein muss (Beine/Rumpfbeuge). Fuehrt der Versuch
# dort Ellbogen oder Schulter, passt das Signal nicht zur Bewegung.
BEIN_MUSTER = re.compile(
    r"squat|lunge|deadlift|rdl|romanian|good_morning|hip_thrust|calf|bridge|sumo|goblet|"
    r"kniebeuge|ausfallschritt|kreuzheben|wadenheben|back_extension|leg_raise|knee_raise|side_leg"
)
# Rumpfdrehung und Seitneigung: kein Gelenk im Bild folgt der Bewegung (Ellbogen/Huefte messen sie nicht).
RUMPF_MUSTER = re.compile(r"rotation|twist|side_bend|seitneigen|chop|lift_low|windmill|rumpf|holzhacken")
# Beine/Rumpf-Uebungen, bei denen Knie/Huefte als Signal in Ordnung ist, auch ohne BEIN_MUSTER.
RUMPF_BEIN_OK = re.compile(
    r"crunch|pull_through|hip_extension|bird_dog"
)
# Geraete der Beine/Huefte: passen in kein Profil, auch wenn der Versuch ein anderes Signal fuehrte.
BEIN_GERAET = re.compile(r"^(leg_|hip_|calf_|hack_|belt_|glute)")

# Regel 6
SENKEN_MUSTER = re.compile(
    r"squat|lunge|kniebeuge|ausfallschritt|pushup|liegestütz|(^|_)dip(_|$)|\bdips\b|"
    r"rdl|romanian|rumänisch|good_morning"
)
BANK_FREIHANTEL = re.compile(r"bankdrücken|bench|incline_press|decline_press|brustpresse|chest_press")

SIGNAL_WORT = {"ellbogen": "Ellbogen", "schulter": "Schulter", "huefte": "Hüfte", "knie": "Knie"}
PROFIL_REIHE = ["ganzkoerper_stehend", "oberkoerper", "stuetz_boden", "liegend", "zug_haengend", "ohne_kamera"]
PROFIL_TITEL = {
    "ganzkoerper_stehend": "Ganzkörper stehend",
    "oberkoerper": "Oberkörper",
    "stuetz_boden": "Stütz am Boden",
    "liegend": "Liegend",
    "zug_haengend": "Zug, hängend",
    "ohne_kamera": "Ohne Kamera",
}
GRUND_BEINGERAET = "kein Profil für Beingeräte im Sitzen"


def lade_versuch():
    with open(VERSUCH, encoding="utf-8", newline="") as f:
        return {z["id"]: z for z in csv.DictReader(f, delimiter=";")}


def signal_aus(fuehrend):
    wort = fuehrend.split(" ")[0].lower()
    return {"ellbogen": "ellbogen", "schulter": "schulter", "hüfte": "huefte", "knie": "knie"}.get(wort)


def geraet_je_uebung(katalog):
    """Gruppe und Name des ersten nicht abgeloesten Geraetetyps, der die Uebung fuehrt."""
    zuordnung = {}
    for g in katalog["equipment"]:
        if g.get("retired"):
            continue
        for key in g["exercises"]:
            zuordnung.setdefault(key, (g["group"], g.get("label") or g["name"]))
    return zuordnung


def beginnt_mit(key, name, gruppe):
    text = f"{key} {name.lower()}"
    if SENKEN_MUSTER.search(text) and "seated_dip" not in key:
        return "senken"
    # Bankdruecken und Brustpresse nur mit freien Gewichten (Kurz-/Langhantel, SZ-Hantel).
    if gruppe == "freihantel" and BANK_FREIHANTEL.search(text) and "drücken" in name.lower():
        return "senken"
    return "heben"


def profil_und_grund(key, name, gruppe, signal):
    """Regel 3 bis 5. Liefert (profil, signal, grund)."""
    text = f"{key} {name.lower()}"
    bein_signal = signal in ("knie", "huefte")

    # Geraete fuer Beine/Huefte: nie ein Profil (Regel 5, gilt auch bei fremdem Signal).
    if gruppe == "geraete" and (bein_signal or BEIN_GERAET.search(key)) and not HAENGEND_MUSTER.search(text):
        return "ohne_kamera", None, GRUND_BEINGERAET

    if RUMPF_MUSTER.search(text) and not re.search(r"external_rotation|internal_rotation|außenrotation|innenrotation", text):
        return "ohne_kamera", None, "Rumpfbewegung: kein Gelenk im Bild folgt ihr"
    if HAENGEND_MUSTER.search(text):
        return "zug_haengend", signal, "Zug oder Hängen: Kamera sieht Arme und Schulter von vorn"

    if gruppe == "eigengewicht" and signal == "ellbogen" and STUETZ_MUSTER.search(text):
        return "stuetz_boden", signal, "Stütz am Boden: Ellbogen beugt und streckt"

    # Signal passt nicht zur Bewegung: lieber ohne Kamera als eine falsche Zaehlung.
    if BEIN_MUSTER.search(text) and not bein_signal:
        return "ohne_kamera", None, "Versuch führte " + SIGNAL_WORT[signal] + ", das passt nicht zur Beinübung"
    if bein_signal and not (BEIN_MUSTER.search(text) or RUMPF_BEIN_OK.search(text) or gruppe == "geraete"):
        return "ohne_kamera", None, "Versuch führte " + SIGNAL_WORT[signal] + ", das passt nicht zur Oberkörperübung"

    liegend = LIEGEND_MUSTER if gruppe in LIEGEND_GRUPPEN else LIEGEND_MUSTER_STRENG
    if gruppe != "geraete" and liegend.search(text):
        return "liegend", signal, "Übung im Liegen oder auf der Bank, Signal " + SIGNAL_WORT[signal]

    if bein_signal:
        return "ganzkoerper_stehend", signal, "Stehende Übung, Signal " + SIGNAL_WORT[signal]
    return "oberkoerper", signal, "Oberkörperübung, Signal " + SIGNAL_WORT[signal]


def vorschlag(u, gruppe, zeile):
    key, name = u["key"], u["name"]
    bm = beginnt_mit(key, name, gruppe)
    standard = {"senken_s": 2.5, "halten_s": 0, "heben_s": 1.5}

    def eintrag(profil, signal, grund, tempo=None):
        return {
            "kamera": OrderedDict([("profil", profil), ("signal", signal), ("seite", "beide"), ("beginnt_mit", bm)]),
            "tempo": tempo or standard,
            "grund": grund,
        }

    # Regel 1
    if not u.get("video"):
        return eintrag("ohne_kamera", None, "Kein Video, keine Kamera")
    if zeile is None:
        return eintrag("ohne_kamera", None, "Kein Urteil aus dem Versuch")
    if zeile["urteil"] != "zählt richtig":
        return eintrag("ohne_kamera", None, "Versuch: " + zeile["urteil"])
    # Regel 2
    if WECHSEL_NAME.search(name.lower()):
        return eintrag("ohne_kamera", None, "Seitenwechsel in der Übung, Kamera zählt das nicht sicher")
    # Regel 3
    signal = signal_aus(zeile["fuehrend"])
    if signal is None:
        return eintrag("ohne_kamera", None, "Versuch ohne führendes Gelenk")
    # Regel 4 und 5
    profil, signal, grund = profil_und_grund(key, name, gruppe, signal)
    if profil == "ohne_kamera":
        return eintrag(profil, None, grund)
    # Regel 7
    tempo = {"senken_s": 3, "halten_s": 1, "heben_s": 2} if profil == "ganzkoerper_stehend" else standard
    return eintrag(profil, signal, grund, tempo)


def zahl(x):
    return str(x).replace(".", ",") if x != int(x) else str(int(x))


def tempo_text(e):
    t, bm = e["tempo"], e["kamera"]["beginnt_mit"]
    teile = {"senken": f"{zahl(t['senken_s'])} s senken", "halten": f"{zahl(t['halten_s'])} s halten", "heben": f"{zahl(t['heben_s'])} s heben"}
    folge = ["senken", "halten", "heben"] if bm == "senken" else ["heben", "halten", "senken"]
    if t["halten_s"] == 0:
        folge.remove("halten")
    return " · ".join(teile[s] for s in folge)


def schreibe_liste(katalog, ergebnis, geraete):
    namen = {u["key"]: u["name"] for u in katalog["exercises"]}
    je_profil = {p: [] for p in PROFIL_REIHE}
    for key, e in ergebnis.items():
        je_profil[e["kamera"]["profil"]].append(key)
    beingeraete = [k for k, e in ergebnis.items() if e["grund"] == GRUND_BEINGERAET]

    z = []
    z.append("# Kamera und Tempo: Zuordnungsvorschlag")
    z.append("")
    z.append("Stand: 24.11.2026. Grundlage: der Kameraversuch vom 23.11.2026 (189 Übungen) und die Regeln in `tools/kamera-zuordnung/vorschlag.py`.")
    z.append("")
    z.append("**Nichts davon steht im Katalog**, bevor Tim die Liste gesehen und das jeweilige Profil den Gütetest bestanden hat. Freigeschaltet ist vorerst nur „Ohne Kamera“.")
    z.append("")
    z.append(f"## Zählung je Profil ({len(ergebnis)} Übungen mit Wiederholungen)")
    z.append("")
    z.append("| Profil | Übungen |")
    z.append("|---|---|")
    for p in PROFIL_REIHE:
        z.append(f"| {PROFIL_TITEL[p]} | {len(je_profil[p])} |")
    z.append("")
    z.append("## Offener Punkt: Beingeräte im Sitzen")
    z.append("")
    z.append(f"Sitzende und liegende Beingeräte passen in keins der sechs Profile. Diese {len(beingeraete)} Übungen stehen deshalb vorerst bei „Ohne Kamera“. Tim entscheidet, ob dafür ein siebtes Profil entstehen soll.")
    z.append("")
    for k in beingeraete:
        z.append(f"- {namen[k]} ({geraete[k][1]})")
    z.append("")
    for p in PROFIL_REIHE:
        z.append(f"## {PROFIL_TITEL[p]} ({len(je_profil[p])})")
        z.append("")
        if not je_profil[p]:
            z.append("Keine Übung.")
            z.append("")
            continue
        z.append("| Übung | Gerät | Signal | Beginnt mit | Tempo | Grund |")
        z.append("|---|---|---|---|---|---|")
        for k in je_profil[p]:
            e = ergebnis[k]
            sig = SIGNAL_WORT[e["kamera"]["signal"]] if e["kamera"]["signal"] else "–"
            bm = "Senken" if e["kamera"]["beginnt_mit"] == "senken" else "Heben"
            z.append(f"| {namen[k]} | {geraete[k][1]} | {sig} | {bm} | {tempo_text(e)} | {e['grund']} |")
        z.append("")
    AUSGABE_MD.write_text("\n".join(z), encoding="utf-8")


def main():
    katalog = json.loads(KATALOG.read_text(encoding="utf-8"))
    versuch = lade_versuch()
    geraete = geraet_je_uebung(katalog)
    ergebnis = OrderedDict()
    for u in katalog["exercises"]:
        if u["volume_kind"] != "reps":
            continue
        gruppe = geraete.get(u["key"], ("", ""))[0]
        ergebnis[u["key"]] = vorschlag(u, gruppe, versuch.get(u["key"]))
    AUSGABE_JSON.write_text(json.dumps(ergebnis, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    schreibe_liste(katalog, ergebnis, {k: v for k, v in geraete.items()})
    zaehlung = Counter(e["kamera"]["profil"] for e in ergebnis.values())
    for p in PROFIL_REIHE:
        print(f"{p}: {zaehlung[p]}")
    print(f"gesamt: {len(ergebnis)}")


if __name__ == "__main__":
    main()
