// Gemeinsame Wertelisten des Trainingsplans (Spec 2026-10-21, Abschnitte 2, 7, 8).
// Eine Quelle fuer Katalog-Validator, Profil, Generator und Datenbank-Checks,
// damit sich die Listen nicht an vier Stellen auseinanderentwickeln.

/** Bausteine einer Trainingseinheit; der Generator fuellt sie je Tag. */
export const BAUSTEINE = [
  "beine_knie",
  "beine_huefte",
  "druecken",
  "ziehen",
  "schulter",
  "arme",
  "rumpf",
  "beine_ergaenzung",
  "cardio",
] as const;
export type Baustein = (typeof BAUSTEINE)[number];

export const PLAN_TYPEN = ["mehrgelenk", "isolation"] as const;
export type PlanTyp = (typeof PLAN_TYPEN)[number];

/** Koerperbereiche, die eine Uebung belastet und die Beschwerden sperren koennen. */
export const BEREICHE = ["knie", "huefte", "unterer_ruecken", "schulter", "ellenbogen_handgelenk"] as const;
export type Bereich = (typeof BEREICHE)[number];

export const FOKUS_BEREICHE = ["brust", "ruecken", "schultern", "arme", "po", "beine", "bauch"] as const;
export type FokusBereich = (typeof FOKUS_BEREICHE)[number];

export const ERFAHRUNG = ["neu", "unregelmaessig", "regelmaessig"] as const;
export type Erfahrung = (typeof ERFAHRUNG)[number];

export const MINUTEN = [30, 45, 60, 75, 90] as const;
export type Minuten = (typeof MINUTEN)[number];

/** Cardio-Arten, aus denen das Mitglied im Wochenraster waehlt (Schluessel, keine Freitexte). */
export const CARDIO_ARTEN = ["laufen", "radfahren", "schwimmen", "wandern", "anderes"] as const;
export type CardioArt = (typeof CARDIO_ARTEN)[number];

/** Diese Bausteine muss jede Einheit abdecken, sonst ist der Plan unvollstaendig. */
export const PFLICHT_BAUSTEINE: readonly Baustein[] = ["beine_knie", "beine_huefte", "druecken", "ziehen"];

/** Planfeld einer Katalog-Uebung; vorhanden heisst: fuer Plaene freigegeben. */
export type PlanFeld = { baustein: Baustein; typ: PlanTyp; bereiche: Bereich[] };
