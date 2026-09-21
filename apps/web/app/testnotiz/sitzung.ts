"use client";

import type { Eintragsentwurf, Laufzeit } from "@/lib/testnotiz/format";
import { zeitstempel } from "@/lib/testnotiz/zeit";
import type { Bild } from "./bildschirmfoto";

/**
 * Der Weg eines Eintrags vom Browser in den Ordner.
 *
 * Die laufende Sitzung steht im `localStorage`: eine Testsitzung im Portal
 * ueberlebt Neuladen, Anmelden und Serverneustart, und all das kommt beim
 * Testen dauernd vor. Die Kennung ist der Ordnername -- mehr merkt sich der
 * Browser nicht, die Wahrheit steht in `sitzung.json`.
 */

const SCHLUESSEL = "testnotiz.sitzung";
const EINGANG = "/api/testnotiz";

export type Sitzungsstand = { sitzung: string; ordner: string; anzahl: number };

export function gemerkteSitzung(): string | null {
  try {
    return window.localStorage.getItem(SCHLUESSEL);
  } catch {
    return null;
  }
}

export function sitzungMerken(id: string | null): void {
  try {
    if (id) window.localStorage.setItem(SCHLUESSEL, id);
    else window.localStorage.removeItem(SCHLUESSEL);
  } catch {
    // Privater Modus ohne Speicher: dann eben nur fuer diese Seite.
  }
}

export async function sitzungStand(id: string): Promise<Sitzungsstand | null> {
  try {
    const antwort = await fetch(`${EINGANG}?sitzung=${encodeURIComponent(id)}`, { cache: "no-store" });
    if (!antwort.ok) return null;
    return (await antwort.json()) as Sitzungsstand;
  } catch {
    return null;
  }
}

export async function eintragSichern(
  entwurf: Eintragsentwurf,
  voll: Bild,
  ausschnitt: Bild | null,
  zusatzkontext: Record<string, string>,
): Promise<Sitzungsstand> {
  const formular = new FormData();
  formular.set("eintrag", JSON.stringify(entwurf));
  formular.set("sitzung", gemerkteSitzung() ?? "");
  formular.set("kopf", JSON.stringify(kopfDaten(new Date())));
  formular.set(
    "ort",
    JSON.stringify({
      pfad: window.location.pathname,
      suche: window.location.search,
      kontext: zusatzkontext,
    }),
  );
  formular.set("voll", voll.blob, "voll.png");
  if (ausschnitt) formular.set("ausschnitt", ausschnitt.blob, "ausschnitt.png");

  const antwort = await fetch(EINGANG, { method: "POST", body: formular });
  if (!antwort.ok) {
    const fehler = await antwort.json().catch(() => ({ error: `HTTP ${antwort.status}` }));
    throw new Error(String((fehler as { error?: string }).error ?? `HTTP ${antwort.status}`));
  }

  const stand = (await antwort.json()) as Sitzungsstand;
  sitzungMerken(stand.sitzung);
  return stand;
}

export function laufzeit(angemeldet: boolean): Laufzeit {
  return {
    online: navigator.onLine,
    // Das Portal schreibt unmittelbar gegen den Server; eine Warteschlange
    // wie in der App gibt es nicht.
    pendingWrites: 0,
    signedIn: angemeldet,
    studioId: studioAusPfad(window.location.pathname),
  };
}

export function studioAusPfad(pfad: string): string | null {
  return pfad.match(/^\/portal\/([^/]+)/)?.[1] ?? null;
}

function kopfDaten(jetzt: Date) {
  return {
    startedAt: zeitstempel(jetzt),
    device: {
      model: browser(),
      os: betriebssystem(),
      screen: {
        width: window.innerWidth,
        height: window.innerHeight,
        scale: window.devicePixelRatio,
      },
    },
  };
}

type Marken = { brands?: { brand: string; version: string }[]; platform?: string };

function marken(): Marken | null {
  return (navigator as Navigator & { userAgentData?: Marken }).userAgentData ?? null;
}

/**
 * "Chrome 143" statt der ganzen Kennung: nur Name und Hauptversion
 * unterscheiden, was einen Fund erklaeren kann.
 */
function browser(): string {
  const gemeldet = marken()?.brands?.find(
    (marke) => !/Not.?A.?Brand|Chromium/i.test(marke.brand),
  );
  if (gemeldet) return `${gemeldet.brand} ${gemeldet.version}`;

  const ua = navigator.userAgent;
  for (const [name, muster] of [
    ["Edge", /Edg\/(\d+)/],
    ["Chrome", /Chrome\/(\d+)/],
    ["Firefox", /Firefox\/(\d+)/],
    ["Safari", /Version\/(\d+).*Safari/],
  ] as const) {
    const treffer = ua.match(muster);
    if (treffer) return `${name} ${treffer[1]}`;
  }
  return "unbekannter Browser";
}

function betriebssystem(): string {
  const platform = marken()?.platform;
  if (platform) return platform;
  const ua = navigator.userAgent;
  if (/Mac OS X/.test(ua)) return "macOS";
  if (/Windows/.test(ua)) return "Windows";
  if (/Android/.test(ua)) return "Android";
  if (/iPhone|iPad/.test(ua)) return "iOS";
  if (/Linux/.test(ua)) return "Linux";
  return "unbekannt";
}
