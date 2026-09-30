"use client";

import type { Protokollzeile } from "@/lib/testnotiz/format";
import { zeitstempel } from "@/lib/testnotiz/zeit";

/**
 * Die letzten Minuten Konsole, wie auf iOS die letzten Minuten OSLog.
 *
 * Der Browser hebt nichts auf, was vor dem Einhaengen lief -- deshalb
 * uebernimmt das Modul `console` beim Start der Seite und legt jede Zeile in
 * einen Ring. Beim Sichern wandern die Zeilen der letzten fuenf Minuten in
 * den Eintrag: der Fehler, der zur Beschwerde gefuehrt hat, steht damit
 * neben dem Bild.
 *
 * **Datenschutz:** anders als OSLog kennt die Konsole keine Kategorien, an
 * denen sich Personendaten ausschliessen liessen. Was das Portal in die
 * Konsole schreibt, steht im Ordner -- der deshalb, wie die Screenshots,
 * nie ins Repository gehoert.
 */

const HOECHSTZAHL = 300;
const ZEICHEN_JE_ZEILE = 400;

type Gemerkt = { zeit: number; zeile: Protokollzeile };

let ring: Gemerkt[] = [];
let installiert = false;

const STUFEN: Record<string, Protokollzeile["level"]> = {
  debug: "debug",
  log: "info",
  info: "info",
  warn: "notice",
  error: "error",
};

export function protokollStarten(): void {
  if (installiert || typeof window === "undefined") return;
  installiert = true;

  for (const [name, stufe] of Object.entries(STUFEN)) {
    const aufsatz = console as unknown as Record<string, unknown>;
    const vorher = aufsatz[name];
    if (typeof vorher !== "function") continue;
    aufsatz[name] = (...werte: unknown[]) => {
      merken(stufe, "console", werte);
      (vorher as (...werte: unknown[]) => void).apply(console, werte);
    };
  }

  window.addEventListener("error", (ereignis) => {
    merken("fault", "fehler", [ereignis.message]);
  });
  window.addEventListener("unhandledrejection", (ereignis) => {
    merken("fault", "fehler", [ereignis.reason]);
  });
}

/** Die Zeilen der letzten `sekunden` bis zum Zeitpunkt der Aufnahme. */
export function protokollSeit(sekunden: number, bis: Date): Protokollzeile[] {
  const frueheste = bis.getTime() - sekunden * 1000;
  return ring
    .filter((gemerkt) => gemerkt.zeit >= frueheste && gemerkt.zeit <= bis.getTime())
    .map((gemerkt) => gemerkt.zeile);
}

function merken(level: Protokollzeile["level"], category: string, werte: unknown[]): void {
  const jetzt = new Date();
  ring.push({
    zeit: jetzt.getTime(),
    zeile: { at: zeitstempel(jetzt), level, category, message: text(werte) },
  });
  if (ring.length > HOECHSTZAHL) ring = ring.slice(-HOECHSTZAHL);
}

function text(werte: unknown[]): string {
  const zusammen = werte
    .map((wert) => {
      if (typeof wert === "string") return wert;
      if (wert instanceof Error) return `${wert.name}: ${wert.message}`;
      try {
        return JSON.stringify(wert);
      } catch {
        return String(wert);
      }
    })
    .join(" ")
    // Zeilenumbrueche wuerden die Protokollzeile in sitzung.md zerreissen.
    .replace(/\s+/g, " ")
    .trim();
  return zusammen.length > ZEICHEN_JE_ZEILE ? `${zusammen.slice(0, ZEICHEN_JE_ZEILE - 1)}…` : zusammen;
}
