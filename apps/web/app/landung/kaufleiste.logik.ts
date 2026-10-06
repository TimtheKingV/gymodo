/**
 * Wann die Kaufleiste steht (Spec 7.3). Rein, damit die Zustandstabelle
 * ohne Browser pruefbar ist; Kaufleiste.tsx liefert nur Messungen.
 */
export type Richtung = "hoch" | "runter";

export type KaufleistenZustand = {
  y: number;
  richtung: Richtung;
  /** Umkehrpunkt: aeusserster Wert in der aktuellen Richtung. */
  wendeY: number;
  sichtbar: boolean;
};

export type KaufleistenMessung = {
  y: number;
  maxY: number;
  ankerVorbei: boolean;
  /** Dokument-y, an dem der Anker unter dem Kopf verschwand. */
  schwelleY: number;
  verdeckt: boolean;
  fokusDrin: boolean;
};

// Gpath wechselt bei 4 px je Frame. Bei 120 Hz und Impulsscrollen kippt das
// am Umkehrpunkt mehrmals; erst 12 px am Stueck sind eine Absicht.
export const HYSTERESE_PX = 12;
// Direkt hinter der Schwelle erscheint die Leiste auch beim Runterscrollen,
// sonst saehe man sie beim ersten Vorbeiscrollen nie.
export const NAHE_PX = 24;

export const KAUFLEISTE_START: KaufleistenZustand = {
  y: 0,
  richtung: "runter",
  wendeY: 0,
  sichtbar: false,
};

export function naechsterZustand(
  vorher: KaufleistenZustand,
  m: KaufleistenMessung,
): KaufleistenZustand {
  // Safari meldet beim Gummiband Werte ausserhalb des Dokuments; die
  // zaehlen nicht als Bewegung.
  const y = Math.min(Math.max(m.y, 0), Math.max(m.maxY, 0));
  let { richtung, wendeY } = vorher;
  const kandidat: Richtung | null = y > vorher.y ? "runter" : y < vorher.y ? "hoch" : null;
  if (kandidat === richtung) {
    wendeY = y;
  } else if (kandidat !== null && Math.abs(y - wendeY) >= HYSTERESE_PX) {
    richtung = kandidat;
    wendeY = y;
  }
  const sichtbar =
    m.ankerVorbei &&
    !m.verdeckt &&
    (m.fokusDrin || richtung === "hoch" || y - m.schwelleY < NAHE_PX);
  return { y, richtung, wendeY, sichtbar };
}
