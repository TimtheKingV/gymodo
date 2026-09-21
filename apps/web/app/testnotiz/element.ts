"use client";

import type { ElementAngabe } from "@/lib/testnotiz/format";

/**
 * Was unter dem Zeiger liegt, als Wert des Formats.
 *
 * Auf iOS liefert das der Accessibility-Baum. Im Browser ist das DOM dieser
 * Baum: `aria-label`, Rolle und Beschriftung stehen an den Elementen selbst.
 * Dazu kommt, was nur React weiss -- der Name der Komponente, aus der das
 * Element stammt.
 */

/** Elemente, die ein Tester meint, wenn er auf ihren Inhalt zeigt. */
const BEDEUTSAM =
  "button, a[href], input, select, textarea, label, summary, [role], [data-testnotiz], [data-testid]";

/**
 * Vom getroffenen Knoten zum gemeinten: wer auf die Schrift in einem Knopf
 * zeigt, meint den Knopf. Hoechstens vier Ebenen hoch, damit nicht die ganze
 * Seite zum Treffer wird.
 */
export function zielElement(treffer: Element): Element {
  if (treffer.matches(BEDEUTSAM)) return treffer;
  let knoten: Element | null = treffer;
  for (let ebene = 0; ebene < 4 && knoten; ebene += 1) {
    knoten = knoten.parentElement;
    if (knoten?.matches(BEDEUTSAM)) return knoten;
  }
  return treffer;
}

export function elementAngabe(element: Element): ElementAngabe {
  const rahmen = element.getBoundingClientRect();
  const herkunft = quelle(element);
  return {
    source: "dom",
    identifier: kennung(element),
    label: beschriftung(element),
    type: herkunft.typ,
    frame: {
      x: rahmen.x,
      y: rahmen.y,
      width: rahmen.width,
      height: rahmen.height,
    },
    file: herkunft.datei,
    line: herkunft.zeile,
  };
}

function kennung(element: Element): string | null {
  return (
    element.getAttribute("data-testnotiz") ??
    element.getAttribute("data-testid") ??
    (element.id || null)
  );
}

function beschriftung(element: Element): string | null {
  const beschriftet = element.getAttribute("aria-labelledby");
  const ausVerweis = beschriftet
    ? beschriftet
        .split(/\s+/)
        .map((id) => element.ownerDocument.getElementById(id)?.textContent ?? "")
        .join(" ")
    : "";

  const kandidaten = [
    element.getAttribute("aria-label"),
    ausVerweis,
    element.getAttribute("alt"),
    element.getAttribute("title"),
    element.textContent,
    element.getAttribute("placeholder"),
    element.getAttribute("value"),
  ];

  for (const kandidat of kandidaten) {
    const text = (kandidat ?? "").replace(/\s+/g, " ").trim();
    if (text) return text.length > 120 ? `${text.slice(0, 119)}…` : text;
  }
  return null;
}

/**
 * Typ, Datei und Zeile. Eine ausdrueckliche Markierung im Markup gewinnt,
 * danach der Komponentenname aus React, zuletzt die Rolle des Elements
 * selbst.
 */
function quelle(element: Element): { typ: string; datei: string | null; zeile: number | null } {
  const markiert = element.getAttribute("data-testnotiz-typ");
  const datei = element.getAttribute("data-testnotiz-datei");
  const zeile = element.getAttribute("data-testnotiz-zeile");
  const ausReact = ausReactFaser(element);

  return {
    typ: markiert ?? ausReact?.typ ?? rolle(element),
    datei: datei ?? ausReact?.datei ?? null,
    zeile: zeile ? Number(zeile) : (ausReact?.zeile ?? null),
  };
}

function rolle(element: Element): string {
  const ausgewiesen = element.getAttribute("role");
  if (ausgewiesen) return ausgewiesen;
  const name = element.tagName.toLowerCase();
  if (name === "input") {
    return `input[type=${element.getAttribute("type") ?? "text"}]`;
  }
  return name;
}

type Faser = {
  return?: Faser | null;
  type?: unknown;
  elementType?: unknown;
  _debugOwner?: Faser | null;
  _debugSource?: { fileName?: string; lineNumber?: number } | null;
};

/**
 * Bausteine des Routers, nicht des Portals. Sie stehen ueber allem, was
 * eine Server-Komponente gerendert hat -- dort fuehrt der Faden also nicht
 * in unseren Quelltext, und "SegmentViewNode" saehe im Eintrag aus wie eine
 * Angabe, waere aber keine. Dann lieber die Rolle des Elements.
 */
const INTERN = new Set([
  "AppRouter",
  "AsyncMetadata",
  "AsyncMetadataOutlet",
  "BailoutToCSR",
  "ClientPageRoot",
  "ClientSegmentRoot",
  "ErrorBoundary",
  "HTTPAccessFallbackBoundary",
  "Head",
  "InnerLayoutRouter",
  "LayoutRouter",
  "LoadingBoundary",
  "MetadataBoundary",
  "NotFoundBoundary",
  "NotFoundErrorBoundary",
  "OuterLayoutRouter",
  "OutletBoundary",
  "PathnameContextProviderAdapter",
  "RedirectBoundary",
  "RedirectErrorBoundary",
  "RenderFromTemplateContext",
  "Router",
  "ScrollAndFocusHandler",
  "SegmentViewNode",
  "SegmentViewStateNode",
  "ServerInsertedHTMLProvider",
  "TemplateContext",
  "ViewportBoundary",
]);

export function istInternerBaustein(name: string): boolean {
  return INTERN.has(name) || /^(Dev|Hot|ReactDev)/.test(name);
}

/**
 * Der Faden zurueck in den Quelltext.
 *
 * React haengt an jeden DOM-Knoten seine Faser (`__reactFiber$…`). Von dort
 * fuehrt `return` nach oben zur naechsten Komponente -- deren Name ist im
 * Entwicklungsbau der aus dem Quelltext. Datei und Zeile stehen nur in
 * React-Fassungen, die `_debugSource` noch fuehren; fehlen sie, bleibt es
 * beim Namen, und der Screen-Pfad im Eintrag traegt den Rest.
 */
function ausReactFaser(element: Element): { typ: string; datei: string | null; zeile: number | null } | null {
  const schluessel = Object.keys(element).find((name) => name.startsWith("__reactFiber$"));
  if (!schluessel) return null;

  let faser: Faser | null | undefined = (element as unknown as Record<string, Faser>)[schluessel];
  for (let ebene = 0; faser && ebene < 12; ebene += 1) {
    const name = komponentenname(faser.type ?? faser.elementType);
    if (name) {
      if (istInternerBaustein(name)) return null;
      const ort = faser._debugSource ?? faser._debugOwner?._debugSource ?? null;
      return {
        typ: name,
        datei: ort?.fileName ? repoPfad(ort.fileName) : null,
        zeile: ort?.lineNumber ?? null,
      };
    }
    faser = faser.return;
  }
  return null;
}

function komponentenname(typ: unknown): string | null {
  if (typeof typ === "function") {
    const benannt = typ as { displayName?: string; name?: string };
    return benannt.displayName ?? (benannt.name || null);
  }
  if (typ && typeof typ === "object") {
    const umhuellt = typ as { displayName?: string; render?: { name?: string }; type?: unknown };
    if (umhuellt.displayName) return umhuellt.displayName;
    if (umhuellt.render?.name) return umhuellt.render.name;
    if (umhuellt.type) return komponentenname(umhuellt.type);
  }
  return null;
}

/** Wie `Quellpfad.relativ` auf iOS: ab `apps/web/` ist der Pfad repo-relativ. */
export function repoPfad(pfad: string): string {
  const treffer = pfad.replace(/\\/g, "/").match(/(apps\/web\/.*)$/);
  return treffer?.[1] ?? pfad.split("/").pop() ?? pfad;
}
