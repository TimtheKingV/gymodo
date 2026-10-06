/**
 * Ohne/Mit, Modell "Schwelle" (Spec 7.2.2). Rein, damit die Tabelle der
 * Faelle ohne Browser laeuft; OhneMit.tsx meldet nur Ereignisse.
 */
export type OhneMitZustand = { mit: boolean; manuell: boolean };
export type OhneMitEreignis =
  | { art: "sonde"; schneidet: boolean }
  | { art: "tipp" }
  | { art: "karteWeg" };

export const OHNE_MIT_START: OhneMitZustand = { mit: false, manuell: false };

export function ohneMitZustand(v: OhneMitZustand, e: OhneMitEreignis): OhneMitZustand {
  switch (e.art) {
    case "sonde":
      // Nach einem Tipp kippte die Sonde den Zustand sonst beim naechsten
      // Scrollpixel zurueck.
      return v.manuell ? v : { mit: e.schneidet, manuell: false };
    case "tipp":
      return { mit: !v.mit, manuell: true };
    case "karteWeg":
      // Draussen schneidet die Sonde nie. Kaeme die Karte von oben zurueck,
      // meldete der Observer keinen Wechsel -- also hier schon auf Ohne.
      return OHNE_MIT_START;
  }
}

const FLUG_X_PX = 160;
const FLUG_Y_PX = 120;
const STAFFEL_MS = 15;

export function pillenFlug(x: number, y: number, i: number) {
  const dx = x - 50;
  const dy = y - 50;
  const laenge = Math.hypot(dx, dy) || 1;
  return {
    sx: Math.round((dx / laenge) * FLUG_X_PX),
    sy: Math.round((dy / laenge) * FLUG_Y_PX),
    r: (i % 2 === 0 ? 1 : -1) * (24 + ((i * 7) % 9)),
    verzoegerung: i * STAFFEL_MS,
  };
}

const FEED_ANLAUF_MS = 120;
const FEED_HALTEN_MS = 1100;
const FEED_GLEITEN_MS = 480;
/** So lange dauert der Rueckflug der Pillen; erst danach springt der Feed auf den Anfang. */
export const RUECKFLUG_MS = 550;

/** Zeitpunkte, zu denen der Feed auf Eintrag 1, 2, ... weiterspringt. Ein Durchgang. */
export function feedZeitplan(anzahl: number): number[] {
  return Array.from(
    { length: Math.max(anzahl - 1, 0) },
    (_, i) => FEED_ANLAUF_MS + FEED_HALTEN_MS + i * (FEED_HALTEN_MS + FEED_GLEITEN_MS),
  );
}

export function feedLage(abstand: number) {
  const a = Math.min(1, Math.abs(abstand));
  return {
    versatz: Math.max(-1.6, Math.min(1.6, abstand)),
    // Die Nachbarn werden kleiner, statt den aktuellen Eintrag zu
    // vergroessern: hochskalierter Text wird unscharf.
    skala: Math.round((1 - 0.45 * a) * 100) / 100,
    deckkraft: Math.abs(abstand) > 1.5 ? 0 : Math.round((1 - 0.72 * a) * 100) / 100,
  };
}
