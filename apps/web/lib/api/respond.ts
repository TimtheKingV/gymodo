import type { DomainErrorCode } from "@fitretro/domain";

/**
 * Einheitliche Fehlerhuelle fuer /api/v1 (Blueprint 8.1).
 *
 * Der Code ist die stabile Zusage an die App, die Meldung ist fuer Menschen.
 */
const STATUS_BY_CODE: Record<DomainErrorCode, number> = {
  validation_failed: 422,
  unauthorized: 401,
  not_found: 404,
  conflict: 409,
  plan_nicht_moeglich: 422,
  profil_unvollstaendig: 422,
  internal: 500,
};

/**
 * `detail` ist optional und erscheint nur, wenn gesetzt -- bestehende
 * Antworten behalten exakt ihre Huelle.
 */
export function errorResponse(
  code: DomainErrorCode,
  message: string,
  detail?: Record<string, unknown>,
): Response {
  return Response.json(
    { error: detail ? { code, message, detail } : { code, message } },
    { status: STATUS_BY_CODE[code] },
  );
}

function isDomainError(
  error: unknown,
): error is Error & { code: DomainErrorCode; detail?: Record<string, unknown> } {
  return (
    error instanceof Error && error.name === "DomainError" && "code" in error
  );
}

/**
 * Bildet einen Fehler der Fachschicht auf die Antwort ab.
 *
 * Alles Unbekannte wird zu einem generischen 500: eine durchgereichte
 * Datenbankmeldung verraet Tabellennamen, Spalten und manchmal fremde Werte.
 */
export function fromDomainError(error: unknown): Response {
  if (isDomainError(error)) {
    return errorResponse(error.code, error.message, error.detail);
  }
  return errorResponse("internal", "Unerwarteter Fehler.");
}
