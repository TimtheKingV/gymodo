import { createHash, randomBytes } from "node:crypto";

/** Laenge eines base64url-kodierten 128-Bit-Tokens. */
const TOKEN_LENGTH = 22;
const TOKEN_PATTERN = /^[A-Za-z0-9_-]{22}$/;

/**
 * Erzeugt einen Tag-Token mit 128 Bit Zufall.
 * Der Token ist ein oeffentlicher Locator, keine Authentisierung.
 */
export function createTagToken(): string {
  return randomBytes(16).toString("base64url");
}

/**
 * SHA-256 des Tokens als Hex. Nur dieser Wert wird gespeichert —
 * der Token selbst verlaesst niemals den Tag beziehungsweise die Anfrage.
 */
export function hashTagToken(token: string): string {
  return createHash("sha256").update(token, "utf8").digest("hex");
}

/** Formatpruefung vor jeder Verwendung. Ersetzt keine Autorisierung. */
export function isValidTagToken(value: string): boolean {
  return value.length === TOKEN_LENGTH && TOKEN_PATTERN.test(value);
}
