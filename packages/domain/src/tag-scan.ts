/**
 * Der Tokenraum als reine Zeichenkettenarbeit -- ohne node:crypto, damit der
 * Sucher diese Datei in einen Browserbundle packen kann. tags.ts bezieht das
 * Muster von hier; dort steht nur noch, was Zufall und Hash braucht.
 */

/** Laenge eines base64url-kodierten 128-Bit-Tokens. */
export const TAG_TOKEN_LENGTH = 22;
export const TAG_TOKEN_PATTERN = /^[A-Za-z0-9_-]{22}$/;

/** Formatpruefung vor jeder Verwendung. Ersetzt keine Autorisierung. */
export function isValidTagToken(value: string): boolean {
  return value.length === TAG_TOKEN_LENGTH && TAG_TOKEN_PATTERN.test(value);
}

// Auf dem Tag steht die vollstaendige Adresse, im Rueckfallweg tippt der
// Trainer nur den Token. Der Anker am Ende laesst Schraegstrich, Abfrage und
// Fragment zu, aber kein 23. Tokenzeichen -- sonst schnitte ein zu langer
// Token stillschweigend auf 22 zurueck und zeigte auf einen fremden Tag.
const AUS_ADRESSE = /\/t\/([A-Za-z0-9_-]{22})(?:[/?#]|$)/;

/**
 * Was der Sucher gelesen hat, als Token -- oder null.
 *
 * Null heisst "das ist kein Tag von uns" und fuehrt zur Antwort *unbekannt*.
 * Erfunden wird hier nichts: ein fremder QR bekommt keine Notloesung.
 */
export function parseTagScan(roh: string): string | null {
  const text = roh.trim();
  if (isValidTagToken(text)) return text;
  const treffer = AUS_ADRESSE.exec(text);
  return treffer ? treffer[1]! : null;
}
