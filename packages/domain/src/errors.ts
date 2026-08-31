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
  | "internal";

export class DomainError extends Error {
  readonly code: DomainErrorCode;

  constructor(code: DomainErrorCode, message: string) {
    super(message);
    this.name = "DomainError";
    this.code = code;
  }
}
