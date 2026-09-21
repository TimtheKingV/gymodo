/**
 * Eine Zip im Browser, ohne Fremdbibliothek.
 *
 * Verfahren ist "store", also ohne Kompression: der Inhalt sind PNG und
 * JPEG (schon komprimiert) und zwei kleine Textdateien -- Deflate braechte
 * Bytes im Promillebereich und dafuer eine Abhaengigkeit. Was bleibt, sind
 * drei Satzarten des Formats: je Datei ein lokaler Kopfsatz vor den Daten,
 * danach das zentrale Verzeichnis, zuletzt der Abschlusssatz (EOCD).
 *
 * Die Namen tragen den Sitzungsordner voran (`2026-09-21-1412/sitzung.md`),
 * entpackt entsteht also genau der Ordner, den Claude Code erwartet.
 */

export type Zipdatei = {
  /** Pfad in der Zip, mit Schraegstrichen, ohne fuehrenden Schraegstrich. */
  name: string;
  daten: Uint8Array;
};

const LOKAL = 0x04034b50;
const ZENTRAL = 0x02014b50;
const ABSCHLUSS = 0x06054b50;
/** Bit 11: die Namen sind UTF-8 kodiert. */
const FLAGGEN = 0x0800;

export function zipBauen(dateien: Zipdatei[], zeit: Date): Uint8Array {
  const kodierer = new TextEncoder();
  const zeitwerte = dosZeit(zeit);

  const teile: Uint8Array[] = [];
  const verzeichnis: Uint8Array[] = [];
  let versatz = 0;

  for (const datei of dateien) {
    const name = kodierer.encode(datei.name);
    const pruefsumme = crc32(datei.daten);

    const kopf = schreiber(30 + name.length);
    kopf.zahl32(LOKAL);
    kopf.zahl16(20); // benoetigte Fassung: 2.0
    kopf.zahl16(FLAGGEN);
    kopf.zahl16(0); // store
    kopf.zahl16(zeitwerte.zeit);
    kopf.zahl16(zeitwerte.datum);
    kopf.zahl32(pruefsumme);
    kopf.zahl32(datei.daten.length);
    kopf.zahl32(datei.daten.length);
    kopf.zahl16(name.length);
    kopf.zahl16(0); // kein Zusatzfeld
    kopf.bytes(name);

    const eintrag = schreiber(46 + name.length);
    eintrag.zahl32(ZENTRAL);
    eintrag.zahl16(20); // erzeugende Fassung
    eintrag.zahl16(20);
    eintrag.zahl16(FLAGGEN);
    eintrag.zahl16(0);
    eintrag.zahl16(zeitwerte.zeit);
    eintrag.zahl16(zeitwerte.datum);
    eintrag.zahl32(pruefsumme);
    eintrag.zahl32(datei.daten.length);
    eintrag.zahl32(datei.daten.length);
    eintrag.zahl16(name.length);
    eintrag.zahl16(0); // Zusatzfeld
    eintrag.zahl16(0); // Kommentar
    eintrag.zahl16(0); // Datentraeger
    eintrag.zahl16(0); // interne Merkmale
    eintrag.zahl32(0); // externe Merkmale
    eintrag.zahl32(versatz);
    eintrag.bytes(name);

    teile.push(kopf.fertig(), datei.daten);
    verzeichnis.push(eintrag.fertig());
    versatz += kopf.laenge + datei.daten.length;
  }

  const verzeichnisLaenge = verzeichnis.reduce((summe, satz) => summe + satz.length, 0);
  const abschluss = schreiber(22);
  abschluss.zahl32(ABSCHLUSS);
  abschluss.zahl16(0); // dieser Datentraeger
  abschluss.zahl16(0); // Datentraeger mit dem Verzeichnis
  abschluss.zahl16(dateien.length);
  abschluss.zahl16(dateien.length);
  abschluss.zahl32(verzeichnisLaenge);
  abschluss.zahl32(versatz);
  abschluss.zahl16(0); // kein Kommentar

  return zusammenfuegen([...teile, ...verzeichnis, abschluss.fertig()]);
}

/** Dieselbe Zip als Blob -- das, was Teilen und Herunterladen brauchen. */
export function zipBlob(dateien: Zipdatei[], zeit: Date): Blob {
  const bytes = zipBauen(dateien, zeit);
  return new Blob([bytes as BlobPart], { type: "application/zip" });
}

/**
 * MS-DOS-Zeit: Sekunden in Zweierschritten, Jahre ab 1980. Vor 1980 gibt es
 * in diesem Format keine Zeit -- solche Daten werden auf den 1.1.1980
 * geklemmt, damit kein entpackendes Werkzeug stolpert.
 */
export function dosZeit(zeit: Date): { zeit: number; datum: number } {
  const jahr = zeit.getFullYear();
  if (jahr < 1980) return { zeit: 0, datum: (1 << 5) | 1 };
  return {
    zeit: (zeit.getHours() << 11) | (zeit.getMinutes() << 5) | Math.floor(zeit.getSeconds() / 2),
    datum: ((jahr - 1980) << 9) | ((zeit.getMonth() + 1) << 5) | zeit.getDate(),
  };
}

const TABELLE = (() => {
  const tabelle = new Uint32Array(256);
  for (let i = 0; i < 256; i += 1) {
    let wert = i;
    for (let bit = 0; bit < 8; bit += 1) {
      wert = wert & 1 ? 0xedb88320 ^ (wert >>> 1) : wert >>> 1;
    }
    tabelle[i] = wert >>> 0;
  }
  return tabelle;
})();

export function crc32(daten: Uint8Array): number {
  let wert = 0xffffffff;
  for (const byte of daten) {
    wert = (TABELLE[(wert ^ byte) & 0xff] as number) ^ (wert >>> 8);
  }
  return (wert ^ 0xffffffff) >>> 0;
}

function schreiber(laenge: number) {
  const puffer = new Uint8Array(laenge);
  const sicht = new DataView(puffer.buffer);
  let stelle = 0;
  return {
    laenge,
    zahl16(wert: number) {
      sicht.setUint16(stelle, wert, true);
      stelle += 2;
    },
    zahl32(wert: number) {
      sicht.setUint32(stelle, wert >>> 0, true);
      stelle += 4;
    },
    bytes(wert: Uint8Array) {
      puffer.set(wert, stelle);
      stelle += wert.length;
    },
    fertig() {
      return puffer;
    },
  };
}

function zusammenfuegen(teile: Uint8Array[]): Uint8Array {
  const gesamt = teile.reduce((summe, teil) => summe + teil.length, 0);
  const alles = new Uint8Array(gesamt);
  let stelle = 0;
  for (const teil of teile) {
    alles.set(teil, stelle);
    stelle += teil.length;
  }
  return alles;
}
