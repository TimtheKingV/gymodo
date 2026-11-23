"""Bruecke zwischen WitMotion-Sensor (Bluetooth) und der Aufnahme-Seite im Browser.

Safari kann aus Webseiten nicht auf Bluetooth zugreifen. Dieses Programm
verbindet sich selbst mit dem Sensor, liefert die Seite aus, reicht jede
Bluetooth-Notification unveraendert (hex) an die Seite weiter und schreibt
gespeicherte Saetze in den Aufnahme-Ordner.

Start (im Terminal, das die Bluetooth-Freigabe hat):
    uv run --with bleak python tools/sensorik-aufnahme/bruecke.py
Dann http://127.0.0.1:8765/ in Safari oeffnen.

Optionen: --ziel <Ordner> (Standard: data/sensoraufnahmen im selben Checkout), --port 8765.
"""
import argparse
import asyncio
import json
import queue
import re
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from bleak import BleakClient, BleakScanner

DIENST = "0000ffe5-0000-1000-8000-00805f9a34fb"
DATEN = "0000ffe4-0000-1000-8000-00805f9a34fb"
BEFEHLE = "0000ffe9-0000-1000-8000-00805f9a34fb"
RATE_50_HZ = bytes([0xFF, 0xAA, 0x03, 0x08, 0x00])
ORDNERNAME = re.compile(r"^\d{4}-\d{2}-\d{2}-\d{4}$")

HIER = Path(__file__).resolve().parent
zustand = {"verbunden": False, "name": None, "meldung": "Suche den Sensor …", "ziel": ""}
hoerer: set[queue.Queue] = set()
sperre = threading.Lock()


def senden(zeile: str) -> None:
    with sperre:
        for q in list(hoerer):
            try:
                q.put_nowait(zeile)
            except queue.Full:  # Seite haengt: lieber diesen Hoerer verlieren als Speicher fuellen
                hoerer.discard(q)


def status(**neu) -> None:
    zustand.update(neu)
    print(zustand["meldung"], flush=True)
    senden(f"event: status\ndata: {json.dumps(zustand)}\n\n")


async def sensor_schleife() -> None:
    while True:
        status(verbunden=False, name=None, meldung="Suche den Sensor …")
        geraet = await BleakScanner.find_device_by_filter(
            lambda d, adv: (d.name or adv.local_name or "").startswith("WT") or DIENST in (adv.service_uuids or []),
            timeout=15,
        )
        if geraet is None:
            status(meldung="Sensor nicht gefunden. Eingeschaltet? Noch mit dem iPhone verbunden? Suche weiter …")
            continue
        getrennt = asyncio.Event()
        try:
            async with BleakClient(geraet, disconnected_callback=lambda _: getrennt.set()) as client:
                await client.write_gatt_char(BEFEHLE, RATE_50_HZ, response=False)
                await client.start_notify(DATEN, lambda _, daten: senden(f"data: {bytes(daten).hex()}\n\n"))
                status(verbunden=True, name=geraet.name or "WitMotion", meldung=f"Sensor {geraet.name} verbunden.")
                await getrennt.wait()
        except Exception as fehler:  # Verbindung verloren oder Aufbau gescheitert: neu suchen
            status(verbunden=False, meldung=f"Verbindung verloren ({fehler}). Suche neu …")
        await asyncio.sleep(1)


def freier_ordner(ziel: Path, kopf: str) -> Path:
    n = 1
    while (ziel / f"{kopf}-{n:02d}").exists():
        n += 1
    return ziel / f"{kopf}-{n:02d}"


class Anfrage(BaseHTTPRequestHandler):
    ziel: Path

    def log_message(self, *_):  # Zugriffe nicht ins Terminal schreiben
        pass

    def antwort(self, code: int, typ: str, inhalt: bytes) -> None:
        self.send_response(code)
        self.send_header("Content-Type", typ)
        self.send_header("Content-Length", str(len(inhalt)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(inhalt)

    def do_GET(self):
        pfad = self.path.split("?")[0]
        if pfad in ("/", "/index.html"):
            self.antwort(200, "text/html; charset=utf-8", (HIER / "index.html").read_bytes())
        elif pfad == "/bruecke":
            self.antwort(200, "application/json", json.dumps(zustand).encode())
        elif pfad == "/strom":
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            q: queue.Queue = queue.Queue(maxsize=5000)
            with sperre:
                hoerer.add(q)
            try:
                self.wfile.write(f"event: status\ndata: {json.dumps(zustand)}\n\n".encode())
                self.wfile.flush()
                while True:
                    try:
                        zeile = q.get(timeout=5)
                    except queue.Empty:
                        zeile = ": lebt\n\n"
                    self.wfile.write(zeile.encode())
                    self.wfile.flush()
            except (BrokenPipeError, ConnectionResetError):
                pass
            finally:
                with sperre:
                    hoerer.discard(q)
        else:
            self.antwort(404, "text/plain", b"nicht gefunden")

    def do_POST(self):
        if self.path != "/speichern":
            return self.antwort(404, "text/plain", b"nicht gefunden")
        try:
            satz = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
            kopf = satz["kopf"]
            if not ORDNERNAME.match(kopf):
                raise ValueError(f"unerwarteter Ordnername {kopf!r}")
            ordner = freier_ordner(self.ziel, kopf)
            ordner.mkdir(parents=True)
            (ordner / "aufnahme.json").write_text(satz["json"], encoding="utf-8")
            (ordner / "messwerte.csv").write_text(satz["csv"], encoding="utf-8")
            print(f"gespeichert: {ordner}", flush=True)
            self.antwort(200, "application/json", json.dumps({"name": ordner.name}).encode())
        except Exception as fehler:
            self.antwort(400, "application/json", json.dumps({"fehler": str(fehler)}).encode())


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--ziel", type=Path, default=HIER.parent.parent / "data" / "sensoraufnahmen")
    p.add_argument("--port", type=int, default=8765)
    a = p.parse_args()
    if not a.ziel.is_dir():
        raise SystemExit(f"Zielordner fehlt: {a.ziel}")
    Anfrage.ziel = a.ziel
    zustand["ziel"] = str(a.ziel)
    server = ThreadingHTTPServer(("127.0.0.1", a.port), Anfrage)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    print(f"Seite: http://127.0.0.1:{a.port}/   Ziel: {a.ziel}", flush=True)
    try:
        asyncio.run(sensor_schleife())
    except KeyboardInterrupt:
        print("beendet")


if __name__ == "__main__":
    main()
