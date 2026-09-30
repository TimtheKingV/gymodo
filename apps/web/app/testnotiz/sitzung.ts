"use client";

import type { Laufzeit, Sitzungskopf } from "@/lib/testnotiz/format";
import { ordnername, zeitstempel } from "@/lib/testnotiz/zeit";

/**
 * Der Kopf einer Sitzung und die Laufzeitwerte je Eintrag.
 *
 * Alles hier entsteht im Browser: seit die Sitzung als Zip herausgeht, gibt
 * es keinen Server mehr, der etwas ergaenzen koennte. Was die Zeilen tragen,
 * ist bewusst knapp -- kein Name, keine E-Mail, kein Token (Spec, Abschnitt
 * Datenschutz).
 */

export function sitzungAnlegenDaten(jetzt: Date): { id: string; kopf: Sitzungskopf } {
  const startedAt = zeitstempel(jetzt);
  return {
    id: ordnername(startedAt),
    kopf: {
      id: "",
      startedAt,
      app: {
        bundleId: "gymodo.web.portal",
        // Auf Vercel der Zweig und der Stand, aus dem die Vorschau gebaut
        // wurde -- genau das, was einen Fund einordnet, wenn ein Kollege ihn
        // schickt. Lokal steht dort, dass es der Dev-Server war.
        version: process.env.NEXT_PUBLIC_VERCEL_GIT_COMMIT_REF ?? "lokal",
        build: process.env.NEXT_PUBLIC_VERCEL_GIT_COMMIT_SHA?.slice(0, 7) ?? "dev",
        configuration: "Debug",
      },
      device: {
        model: browser(),
        os: betriebssystem(),
        screen: {
          width: window.innerWidth,
          height: window.innerHeight,
          scale: window.devicePixelRatio,
        },
      },
    },
  };
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
  if (/iPhone|iPad/.test(ua)) return "iOS";
  if (/Android/.test(ua)) return "Android";
  if (/Mac OS X/.test(ua)) return "macOS";
  if (/Windows/.test(ua)) return "Windows";
  if (/Linux/.test(ua)) return "Linux";
  return "unbekannt";
}
