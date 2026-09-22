"use client";

import type { Eintragsentwurf, Screen, Sitzungskopf } from "@/lib/testnotiz/format";

/**
 * Die Sitzung lebt im Browser, nicht mehr auf einem Server.
 *
 * IndexedDB und nicht localStorage: dort passen Blobs unveraendert hinein,
 * waehrend localStorage bei fuenf Megabyte endet und Bilder erst noch in
 * Base64 aufblaehen wuerde. Und sie muss halten -- eine Testsitzung am Handy
 * ueberlebt Seitenwechsel, Anmeldung und Neuladen, sonst ist die Arbeit weg,
 * bevor die Zip entsteht.
 *
 * Jede Funktion faengt ihre Fehler ab und meldet sie als Wert: im privaten
 * Fenster von Safari gibt es keine Datenbank, und ein volles Geraet lehnt
 * das Schreiben ab. Beides soll die Oberflaeche sagen koennen, statt still
 * Eintraege zu verlieren.
 */

const DATENBANK = "testnotiz";
const FASSUNG = 1;
const SITZUNG = "sitzung";
const EINTRAEGE = "eintraege";
const SCHLUESSEL = "aktuell";

export type Sitzungsstand = {
  id: string;
  kopf: Sitzungskopf;
};

export type GespeicherterEintrag = {
  index: number;
  entwurf: Eintragsentwurf;
  screen: Screen | null;
  voll: Blob | null;
  ausschnitt: Blob | null;
};

function oeffnen(): Promise<IDBDatabase> {
  return new Promise((gelingt, scheitert) => {
    if (typeof indexedDB === "undefined") {
      scheitert(new Error("Dieser Browser hat keine Datenbank."));
      return;
    }
    const anfrage = indexedDB.open(DATENBANK, FASSUNG);
    anfrage.onupgradeneeded = () => {
      const db = anfrage.result;
      if (!db.objectStoreNames.contains(SITZUNG)) db.createObjectStore(SITZUNG);
      if (!db.objectStoreNames.contains(EINTRAEGE)) {
        db.createObjectStore(EINTRAEGE, { keyPath: "index" });
      }
    };
    anfrage.onsuccess = () => gelingt(anfrage.result);
    anfrage.onerror = () => scheitert(anfrage.error ?? new Error("Datenbank nicht zu oeffnen."));
    anfrage.onblocked = () => scheitert(new Error("Datenbank ist von einem anderen Tab belegt."));
  });
}

function abschliessen(vorgang: IDBTransaction): Promise<void> {
  return new Promise((gelingt, scheitert) => {
    vorgang.oncomplete = () => gelingt();
    vorgang.onabort = () => scheitert(vorgang.error ?? new Error("Schreiben abgebrochen."));
    vorgang.onerror = () => scheitert(vorgang.error ?? new Error("Schreiben fehlgeschlagen."));
  });
}

function ergebnis<T>(anfrage: IDBRequest<T>): Promise<T> {
  return new Promise((gelingt, scheitert) => {
    anfrage.onsuccess = () => gelingt(anfrage.result);
    anfrage.onerror = () => scheitert(anfrage.error ?? new Error("Lesen fehlgeschlagen."));
  });
}

export async function sitzungLesen(): Promise<Sitzungsstand | null> {
  const db = await oeffnen();
  try {
    const vorgang = db.transaction(SITZUNG, "readonly");
    const stand = await ergebnis<Sitzungsstand | undefined>(
      vorgang.objectStore(SITZUNG).get(SCHLUESSEL),
    );
    return stand ?? null;
  } finally {
    db.close();
  }
}

export async function sitzungAnlegen(stand: Sitzungsstand): Promise<void> {
  const db = await oeffnen();
  try {
    const vorgang = db.transaction(SITZUNG, "readwrite");
    vorgang.objectStore(SITZUNG).put(stand, SCHLUESSEL);
    await abschliessen(vorgang);
  } finally {
    db.close();
  }
}

/**
 * Haengt einen Eintrag an und vergibt seine Nummer im selben Vorgang -- zwei
 * schnell nacheinander gesicherte Eintraege bekaemen sonst dieselbe.
 */
export async function eintragAnhaengen(
  eintrag: Omit<GespeicherterEintrag, "index">,
): Promise<number> {
  const db = await oeffnen();
  try {
    const vorgang = db.transaction(EINTRAEGE, "readwrite");
    const lager = vorgang.objectStore(EINTRAEGE);
    const index = (await ergebnis(lager.count())) + 1;
    lager.put({ ...eintrag, index });
    await abschliessen(vorgang);
    return index;
  } finally {
    db.close();
  }
}

export async function eintraegeLesen(): Promise<GespeicherterEintrag[]> {
  const db = await oeffnen();
  try {
    const vorgang = db.transaction(EINTRAEGE, "readonly");
    const alle = await ergebnis<GespeicherterEintrag[]>(vorgang.objectStore(EINTRAEGE).getAll());
    return alle.sort((a, b) => a.index - b.index);
  } finally {
    db.close();
  }
}

export async function anzahlLesen(): Promise<number> {
  const db = await oeffnen();
  try {
    const vorgang = db.transaction(EINTRAEGE, "readonly");
    return await ergebnis(vorgang.objectStore(EINTRAEGE).count());
  } finally {
    db.close();
  }
}

export async function sitzungVerwerfen(): Promise<void> {
  const db = await oeffnen();
  try {
    const vorgang = db.transaction([SITZUNG, EINTRAEGE], "readwrite");
    vorgang.objectStore(SITZUNG).clear();
    vorgang.objectStore(EINTRAEGE).clear();
    await abschliessen(vorgang);
  } finally {
    db.close();
  }
}

/**
 * Wie viele Bytes die Bilder dieser Sitzung belegen. Am Handy sind
 * Screenshots ein halbes bis zwei Megabyte; ab einer gewissen Menge soll das
 * Sitzungsblatt zum Teilen raten, bevor der Browser das Schreiben verweigert.
 */
export function groesse(eintraege: GespeicherterEintrag[]): number {
  return eintraege.reduce(
    (summe, eintrag) => summe + (eintrag.voll?.size ?? 0) + (eintrag.ausschnitt?.size ?? 0),
    0,
  );
}
