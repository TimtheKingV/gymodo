// Ablauflogik im Studio (Spec 2026-10-21, Abschnitt 5, F2, F17, F19). Reine Funktionen ohne I/O:
// Der Ablaufstatus wird auch auf dem Geraet berechnet (F17), daher teilen sich TypeScript und
// Swift die Testfaelle in fixtures/plan-ablauf.json. Diese Datei ist die Referenz.

export type PositionStatus = "offen" | "erledigt" | "optional" | "getauscht";

export type AblaufPosition = {
  key: string;
  exerciseId: string;
  /** Gilt fuer die wirksame Uebung, bei Tausch also fuer die Ersatzuebung. */
  hauptmuskeln: string[];
  cardio: boolean;
  status: PositionStatus;
  ersatzExerciseId: string | null;
};

export type AblaufZustand = { positionen: AblaufPosition[]; ungeplanteGesehen: string[] };

export type AblaufSatz = { exerciseId: string; hauptmuskeln: string[]; cardio: boolean };

// Wirksam ist die Ersatzuebung, sobald getauscht wurde; sonst die geplante.
const wirksam = (p: AblaufPosition): string => p.ersatzExerciseId ?? p.exerciseId;

// Nur diese Stati koennen noch durch einen Satz abgehakt werden (erledigt ist schon fertig).
const abhakbar = (p: AblaufPosition): boolean =>
  p.status === "offen" || p.status === "getauscht" || p.status === "optional";

/**
 * Verbucht einen gespeicherten Satz. Regel 1: passende Position wird erledigt.
 * Regel 2: sonst ungeplante Uebung, hoechstens einmal je Uebung genau eine Position optional.
 * Cardio und Kraft beruehren sich nie, damit ein Kraftsatz keine Cardio-Position verdraengt.
 */
export function ablaufNachSatz(z: AblaufZustand, satz: AblaufSatz): AblaufZustand {
  const gleicheArt = (p: AblaufPosition) => p.cardio === satz.cardio;

  // Regel 1. Bei Cardio zaehlt jedes Geraet (F19), bei Kraft die erste passende Position in
  // Planreihenfolge, damit eine doppelt geplante Uebung nicht auf einen Schlag abgehakt wird.
  const passt = (p: AblaufPosition) =>
    gleicheArt(p) && abhakbar(p) && (satz.cardio || wirksam(p) === satz.exerciseId);
  const trefferIdx = z.positionen.findIndex(passt);
  if (trefferIdx >= 0) {
    return {
      ...z,
      positionen: z.positionen.map((p, i) =>
        (satz.cardio ? passt(p) : i === trefferIdx) ? { ...p, status: "erledigt" as const } : p,
      ),
    };
  }

  // Regel 2. Fuehrt irgendeine Position (auch erledigt/optional) die Uebung, ist sie geplant.
  if (satz.cardio) return z;
  if (z.positionen.some((p) => !p.cardio && wirksam(p) === satz.exerciseId)) return z;
  if (z.ungeplanteGesehen.includes(satz.exerciseId)) return z;

  const gesehen = [...z.ungeplanteGesehen, satz.exerciseId];
  let besterIdx = -1;
  let besteAnzahl = 0;
  z.positionen.forEach((p, i) => {
    if (p.cardio || (p.status !== "offen" && p.status !== "getauscht")) return;
    const gemeinsam = p.hauptmuskeln.filter((m) => satz.hauptmuskeln.includes(m)).length;
    // Strikt groesser: bei Gleichstand gewinnt die zuerst im Plan.
    if (gemeinsam > besteAnzahl) {
      besteAnzahl = gemeinsam;
      besterIdx = i;
    }
  });
  return {
    ungeplanteGesehen: gesehen,
    positionen:
      besterIdx < 0
        ? z.positionen
        : z.positionen.map((p, i) => (i === besterIdx ? { ...p, status: "optional" as const } : p)),
  };
}

/** Tauscht eine Position dauerhaft; Cardio und bereits gezaehlte Positionen bleiben unveraendert. */
export function ablaufTauschen(
  z: AblaufZustand,
  positionKey: string,
  ersatz: { exerciseId: string; hauptmuskeln: string[] },
): AblaufZustand {
  return {
    ...z,
    positionen: z.positionen.map((p) =>
      p.key === positionKey && !p.cardio && (p.status === "offen" || p.status === "getauscht")
        ? {
            ...p,
            status: "getauscht" as const,
            ersatzExerciseId: ersatz.exerciseId,
            hauptmuskeln: ersatz.hauptmuskeln,
          }
        : p,
    ),
  };
}

/** Eine Einheit zaehlt fuer die Folge, sobald mindestens eine Position erledigt oder optional ist. */
export function einheitZaehlt(z: AblaufZustand): boolean {
  return z.positionen.some((p) => p.status === "erledigt" || p.status === "optional");
}

/** Nachfolger in der Folge; nach der letzten wieder die erste, unbekannt oder null gibt die erste. */
export function naechsteEinheitKey(einheitKeys: string[], zuletztGezaehlt: string | null): string {
  const idx = zuletztGezaehlt === null ? -1 : einheitKeys.indexOf(zuletztGezaehlt);
  return einheitKeys[(idx + 1) % einheitKeys.length]!;
}
