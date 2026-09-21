"use client";

import type { Ausschnittsrahmen, Rechteck } from "@/lib/testnotiz/format";

/**
 * Das Bildschirmfoto im Browser.
 *
 * Es gibt keine Entsprechung zu `UIWindowScene.snapshot` -- eine Seite kann
 * sich nicht selbst abmalen. Die beiden Wege waeren: das DOM in ein SVG
 * giessen (haeufig falsch: Schriften, Filter, fremde Bilder) oder die
 * Bildschirmfreigabe. Hier die Freigabe: sie zeigt genau die Pixel, ueber
 * die sich der Tester beschwert.
 *
 * Gefragt wird einmal je Sitzung. Der Datenstrom bleibt danach offen, jedes
 * weitere Foto kostet keinen Dialog mehr. Wie auf iOS das Overlay-Fenster
 * beim Foto ausgelassen wird, wird hier die Oberflaeche des Moduls kurz
 * unsichtbar geschaltet -- Knopf und Menue stehen sonst im Bild.
 */

export type Bild = {
  leinwand: HTMLCanvasElement;
  blob: Blob;
  /** Object-URL fuer die Vorschau; `freigeben()` gibt ihn zurueck. */
  url: string;
  breite: number;
  hoehe: number;
};

let strom: MediaStream | null = null;
let video: HTMLVideoElement | null = null;

/**
 * Kann dieser Browser den Tab ueberhaupt freigeben? Am Handy nicht: weder
 * iOS-Safari noch Chrome fuer Android kennen `getDisplayMedia`. Dort haengt
 * der Tester seinen eigenen Screenshot an.
 */
export function freigabeMoeglich(): boolean {
  return typeof navigator !== "undefined" && typeof navigator.mediaDevices?.getDisplayMedia === "function";
}

export function freigabeAktiv(): boolean {
  return strom !== null && strom.getVideoTracks().some((spur) => spur.readyState === "live");
}

export async function freigabeAnfordern(): Promise<void> {
  if (freigabeAktiv()) return;
  freigabeBeenden();

  if (!navigator.mediaDevices?.getDisplayMedia) {
    throw new Error("Dieser Browser kann den Tab nicht freigeben.");
  }

  strom = await tabFreigeben();
  strom.getVideoTracks().forEach((spur) => {
    spur.addEventListener("ended", () => freigabeBeenden());
  });

  const element = document.createElement("video");
  element.muted = true;
  element.playsInline = true;
  // Ausserhalb des Sichtfelds statt display:none -- ein nicht angezeigtes
  // Video liefert in manchen Browsern keine Bilder, und im Bild stehen darf
  // es auch nicht (sonst filmt es sich selbst).
  element.style.cssText = "position:fixed;top:0;left:-10000px;width:2px;height:2px;opacity:0;";
  element.srcObject = strom;
  document.body.appendChild(element);
  video = element;

  await element.play();
  await bereit(element);
}

export function freigabeBeenden(): void {
  strom?.getTracks().forEach((spur) => spur.stop());
  strom = null;
  video?.remove();
  video = null;
}

/**
 * Ein Foto des sichtbaren Bereichs. `ohne` wird fuer die Dauer der Aufnahme
 * unsichtbar geschaltet.
 */
export async function aufnehmen(ohne: HTMLElement | null): Promise<Bild> {
  if (!freigabeAktiv() || !video) {
    throw new Error("Keine Freigabe.");
  }
  const element = video;

  const vorher = ohne?.style.visibility ?? "";
  if (ohne) ohne.style.visibility = "hidden";
  try {
    await neuesBild(element);
    const leinwand = document.createElement("canvas");
    leinwand.width = element.videoWidth;
    leinwand.height = element.videoHeight;
    const kontext = leinwand.getContext("2d");
    if (!kontext) throw new Error("Kein 2D-Kontext.");
    kontext.drawImage(element, 0, 0);
    return await bildAus(leinwand);
  } finally {
    if (ohne) ohne.style.visibility = vorher;
  }
}

/**
 * Schneidet ein Rechteck in CSS-Pixeln aus dem Foto. Der Rahmen kommt in
 * beiden Massen zurueck, wie der Vertrag es verlangt: `points` wie im
 * Fenster gezogen, `pixels` nach aussen auf ganze Bildpunkte gerundet und
 * aufs Bild beschnitten.
 */
export async function schneiden(
  voll: Bild,
  rahmen: Rechteck,
): Promise<{ bild: Bild | null; rahmen: Ausschnittsrahmen } | null> {
  const skalaX = voll.breite / window.innerWidth;
  const skalaY = voll.hoehe / window.innerHeight;

  const links = klemmen(Math.floor(rahmen.x * skalaX), 0, voll.breite);
  const oben = klemmen(Math.floor(rahmen.y * skalaY), 0, voll.hoehe);
  const rechts = klemmen(Math.ceil((rahmen.x + rahmen.width) * skalaX), 0, voll.breite);
  const unten = klemmen(Math.ceil((rahmen.y + rahmen.height) * skalaY), 0, voll.hoehe);
  const breite = rechts - links;
  const hoehe = unten - oben;
  if (breite < 1 || hoehe < 1) return null;

  const rahmenBeide: Ausschnittsrahmen = {
    points: { x: rahmen.x, y: rahmen.y, width: rahmen.width, height: rahmen.height },
    pixels: { x: links, y: oben, width: breite, height: hoehe },
  };

  // Deckt der Ausschnitt das ganze Foto, waere das Ausschnittbild Pixel fuer
  // Pixel das Vollbild -- dann bleibt es weg (wie `seiteGewaehlt()` auf iOS).
  if (links === 0 && oben === 0 && breite === voll.breite && hoehe === voll.hoehe) {
    return { bild: null, rahmen: rahmenBeide };
  }

  const leinwand = document.createElement("canvas");
  leinwand.width = breite;
  leinwand.height = hoehe;
  const kontext = leinwand.getContext("2d");
  if (!kontext) return null;
  kontext.drawImage(voll.leinwand, links, oben, breite, hoehe, 0, 0, breite, hoehe);
  return { bild: await bildAus(leinwand), rahmen: rahmenBeide };
}

/** Der ganze sichtbare Bereich als Rechteck in CSS-Pixeln. */
export function ganzeSeite(): Rechteck {
  return { x: 0, y: 0, width: window.innerWidth, height: window.innerHeight };
}

export function freigeben(...bilder: (Bild | null | undefined)[]): void {
  for (const bild of bilder) {
    if (bild) URL.revokeObjectURL(bild.url);
  }
}

async function tabFreigeben(): Promise<MediaStream> {
  const gewuenscht = {
    video: { displaySurface: "browser" },
    audio: false,
    // Chrome bietet damit den eigenen Tab schon ausgewaehlt an -- ein Klick
    // statt einer Liste. Andere Browser kennen die Felder nicht.
    preferCurrentTab: true,
    selfBrowserSurface: "include",
    surfaceSwitching: "exclude",
  } as DisplayMediaStreamOptions;

  try {
    return await navigator.mediaDevices.getDisplayMedia(gewuenscht);
  } catch (fehler) {
    // NotAllowedError heisst: abgelehnt. Nur bei einem Streit ueber die
    // Optionen lohnt der zweite, schlichte Versuch.
    if (fehler instanceof DOMException && fehler.name === "NotAllowedError") throw fehler;
    return await navigator.mediaDevices.getDisplayMedia({ video: true, audio: false });
  }
}

function bereit(element: HTMLVideoElement): Promise<void> {
  if (element.videoWidth > 0) return Promise.resolve();
  return new Promise((fertig) => {
    element.addEventListener("loadedmetadata", () => fertig(), { once: true });
  });
}

/**
 * Wartet auf ein Bild, das nach dem Ausblenden der Oberflaeche entstanden
 * ist: erst zwei Bildschirmaktualisierungen (die Seite zeichnet ohne das
 * Modul), dann zwei Bilder des Datenstroms.
 */
async function neuesBild(element: HTMLVideoElement): Promise<void> {
  await new Promise<void>((fertig) =>
    requestAnimationFrame(() => requestAnimationFrame(() => fertig())),
  );

  const rvfc = (
    element as HTMLVideoElement & {
      requestVideoFrameCallback?: (rueckruf: () => void) => number;
    }
  ).requestVideoFrameCallback;

  if (typeof rvfc !== "function") {
    await warten(150);
    return;
  }

  await Promise.race([
    new Promise<void>((fertig) => {
      let uebrig = 2;
      const naechstes = () =>
        rvfc.call(element, () => {
          uebrig -= 1;
          if (uebrig > 0) naechstes();
          else fertig();
        });
      naechstes();
    }),
    // Ein Tab im Hintergrund liefert keine Bilder mehr; dann lieber das
    // letzte als gar keines.
    warten(400),
  ]);
}

function warten(millisekunden: number): Promise<void> {
  return new Promise((fertig) => setTimeout(fertig, millisekunden));
}

async function bildAus(leinwand: HTMLCanvasElement): Promise<Bild> {
  const blob = await new Promise<Blob | null>((fertig) => leinwand.toBlob(fertig, "image/png"));
  if (!blob) throw new Error("Bild liess sich nicht kodieren.");
  return {
    leinwand,
    blob,
    url: URL.createObjectURL(blob),
    breite: leinwand.width,
    hoehe: leinwand.height,
  };
}

function klemmen(wert: number, klein: number, gross: number): number {
  return Math.min(Math.max(wert, klein), gross);
}
