import { createHash, randomBytes } from "node:crypto";
import { TAG_TOKEN_LENGTH } from "./tag-scan.js";

export { isValidTagToken } from "./tag-scan.js";

/**
 * Erzeugt einen Tag-Token mit 128 Bit Zufall.
 * Der Token ist ein oeffentlicher Locator, keine Authentisierung.
 */
export function createTagToken(): string {
  const token = randomBytes(16).toString("base64url");
  // Sicherung gegen ein Auseinanderlaufen von Erzeuger und Muster: beides
  // steht jetzt in zwei Dateien, und der Erzeuger haelt sich an die andere.
  if (token.length !== TAG_TOKEN_LENGTH) {
    throw new Error(`Tokenlaenge ${token.length}, erwartet ${TAG_TOKEN_LENGTH}`);
  }
  return token;
}

/**
 * SHA-256 des Tokens als Hex. Seit 0026 erzeugt die Datenbank ihn selbst als
 * generierte Spalte; diese Funktion bleibt fuer das Betreiberwerkzeug.
 */
export function hashTagToken(token: string): string {
  return createHash("sha256").update(token, "utf8").digest("hex");
}
