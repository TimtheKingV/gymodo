"use client";

import {
  FORMAT_KENNUNG,
  PLATTFORM,
  type Eintrag,
  type Sitzung,
  sitzungJson,
} from "@/lib/testnotiz/format";
import { rendern } from "@/lib/testnotiz/markdown";
import { zipBlob } from "@/lib/testnotiz/zip";
import type { GespeicherterEintrag, Sitzungsstand } from "./speicher";

/**
 * Aus der Sitzung im Browser wird eine Zip -- entpackt ergibt sie genau den
 * Ordner, den Claude Code liest.
 *
 * Das ist der Ersatz fuer den Dev-Server, der den Ordner frueher selbst
 * geschrieben hat: am Handy gibt es keinen, und ein Kollege hat das
 * Repository gar nicht. Wer die Zip bekommt, entpackt sie nach
 * `apps/web/testnotizen/`.
 */

/** Dateiendung nach dem Typ des Bildes: die Freigabe liefert PNG, die
    Fotomediathek eines iPhones auch mal JPEG. */
function endung(blob: Blob): string {
  if (blob.type === "image/jpeg") return "jpg";
  if (blob.type === "image/webp") return "webp";
  return "png";
}

export type Buendel = {
  dateiname: string;
  blob: Blob;
  /** Der Ordnername in der Zip, zugleich `session.id`. */
  ordner: string;
};

export async function sitzungBuendeln(
  stand: Sitzungsstand,
  gespeicherte: GespeicherterEintrag[],
): Promise<Buendel> {
  const dateien: { name: string; daten: Uint8Array }[] = [];
  const eintraege: Eintrag[] = [];

  for (const gespeichert of gespeicherte) {
    const praefix = String(gespeichert.index).padStart(2, "0");

    let screenshot: string | null = null;
    if (gespeichert.voll) {
      screenshot = `${praefix}-voll.${endung(gespeichert.voll)}`;
      dateien.push({ name: screenshot, daten: await bytes(gespeichert.voll) });
    }

    let crop: string | null = null;
    if (gespeichert.ausschnitt) {
      crop = `${praefix}-ausschnitt.${endung(gespeichert.ausschnitt)}`;
      dateien.push({ name: crop, daten: await bytes(gespeichert.ausschnitt) });
    }

    eintraege.push({
      ...gespeichert.entwurf,
      index: gespeichert.index,
      screen: gespeichert.screen,
      screenshot,
      crop,
      // Sprachnotizen gibt es im Portal nicht; die Felder bleiben Teil des
      // Vertrags und stehen auf null.
      audio: null,
      transcript: null,
    });
  }

  const sitzung: Sitzung = {
    format: FORMAT_KENNUNG,
    platform: PLATTFORM,
    session: { ...stand.kopf, id: stand.id },
    entries: eintraege,
  };

  const text = new TextEncoder();
  dateien.push({ name: "sitzung.json", daten: text.encode(sitzungJson(sitzung)) });
  dateien.push({ name: "sitzung.md", daten: text.encode(rendern(sitzung)) });

  return {
    ordner: stand.id,
    dateiname: `${stand.id}.zip`,
    blob: zipBlob(
      dateien.map((datei) => ({ name: `${stand.id}/${datei.name}`, daten: datei.daten })),
      new Date(),
    ),
  };
}

export type Weitergabe = "geteilt" | "geladen" | "abgebrochen";

/**
 * Erst das Share-Sheet (am Handy der kurze Weg: AirDrop, Mail, WhatsApp),
 * sonst der gewoehnliche Download -- Chrome am Rechner teilt keine Dateien.
 * Beides braucht die Geste des Klicks, der hierher gefuehrt hat.
 */
export async function weitergeben(buendel: Buendel): Promise<Weitergabe> {
  const datei = new File([buendel.blob], buendel.dateiname, { type: "application/zip" });

  if (navigator.canShare?.({ files: [datei] })) {
    try {
      await navigator.share({ files: [datei], title: buendel.ordner });
      return "geteilt";
    } catch (grund) {
      // Wer das Blatt wegwischt, hat nicht abgebrochen, weil etwas kaputt
      // ist -- dann soll auch kein Download hinterherkommen.
      if (grund instanceof DOMException && grund.name === "AbortError") return "abgebrochen";
    }
  }

  const url = URL.createObjectURL(buendel.blob);
  const verweis = document.createElement("a");
  verweis.href = url;
  verweis.download = buendel.dateiname;
  document.body.appendChild(verweis);
  verweis.click();
  verweis.remove();
  // Erst freigeben, wenn der Browser den Download begonnen hat.
  setTimeout(() => URL.revokeObjectURL(url), 10_000);
  return "geladen";
}

async function bytes(blob: Blob): Promise<Uint8Array> {
  return new Uint8Array(await blob.arrayBuffer());
}
