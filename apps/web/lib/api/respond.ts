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
  internal: 500,
};

export function errorResponse(
  code: DomainErrorCode,
  message: string,
): Response {
  return Response.json(
    { error: { code, message } },
    { status: STATUS_BY_CODE[code] },
  );
}

function isDomainError(
  error: unknown,
): error is Error & { code: DomainErrorCode } {
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
    return errorResponse(error.code, error.message);
  }
  return errorResponse("internal", "Unerwarteter Fehler.");
}
