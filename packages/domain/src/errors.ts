import type { Baustein } from "./trainingsplan-typen.js";

/**
 * Fehler der Fachschicht. Der Code ist die stabile Zusage nach aussen --
 * die HTTP-Route und die Server Action bilden ihn auf ihren Kanal ab, die
 * Meldung ist fuer Menschen und darf sich aendern.
 *
 * Bewusst arm an Details: eine Fehlermeldung darf nie verraten, ob eine
 * fremde Zeile existiert. Deshalb liefert ein Geraet aus einem fremden
 * Studio `not_found` und nicht `forbidden`.
 */
export type DomainErrorCode =
  | "validation_failed"
  | "unauthorized"
  | "not_found"
  | "conflict"
  | "plan_nicht_moeglich"
  | "profil_unvollstaendig"
  | "internal";

export class DomainError extends Error {
  readonly code: DomainErrorCode;
  /**
   * Optionale, maschinenlesbare Feinheit unter dem stabilen Code (etwa
   * `{ fehlt: ["tage"] }` bei profil_unvollstaendig). Die App braucht sie, um gezielt zu
   * reagieren, ohne die Meldung zu parsen; nie fremde Daten hineinlegen.
   */
  readonly detail?: Record<string, unknown>;

  constructor(code: DomainErrorCode, message: string, detail?: Record<string, unknown>) {
    super(message);
    this.name = "DomainError";
    this.code = code;
    if (detail) this.detail = detail;
  }
}

// Menschliche Namen der Bausteine fuer Meldungen; der rohe Schluessel steht im detail.
const BAUSTEIN_NAME: Record<Baustein, string> = {
  beine_knie: "Beine (Kniestreckung)",
  beine_huefte: "Beine (Hüfte)",
  druecken: "Drücken",
  ziehen: "Ziehen",
  schulter: "Schulter",
  arme: "Arme",
  rumpf: "Rumpf",
  beine_ergaenzung: "Beine (Ergänzung)",
  cardio: "Cardio",
};

/**
 * Der Generator findet fuer einen Pflichtbaustein keine Uebung. Lieber ein klarer
 * Fehler als ein stiller Plan ohne Pflichtbaustein (Review-Fokus 1 und 2).
 * Der Name bleibt "DomainError", damit fromDomainError ihn ohne Sonderfall abbildet.
 */
export class PlanNichtMoeglichError extends DomainError {
  readonly baustein: Baustein;
  /** kein_geraet: im Studio gibt es keinen Kandidaten; beschwerden: alle gemieden. */
  readonly grund: "kein_geraet" | "beschwerden";

  constructor(baustein: Baustein, grund: "kein_geraet" | "beschwerden") {
    super(
      "plan_nicht_moeglich",
      grund === "kein_geraet"
        ? `Für den Bereich ${BAUSTEIN_NAME[baustein]} gibt es im Studio kein passendes Gerät.`
        : `Für den Bereich ${BAUSTEIN_NAME[baustein]} passt wegen deiner Beschwerden keine Übung.`,
      { baustein, grund },
    );
    this.baustein = baustein;
    this.grund = grund;
  }
}
