/**
 * Wohin es nach Anmelden oder Registrieren geht (Testnotiz 25.09., #6).
 *
 * Wer einen Einladungslink oeffnet und noch kein Konto hat, legt eins an
 * und soll danach wieder auf der Einladung stehen, nicht auf der
 * Startseite. Der Rueckweg reist als ?weiter= mit.
 *
 * Nur genau diese eine Form wird durchgelassen, nicht "irgendein Pfad, der
 * mit / beginnt": "//evil.example" beginnt auch mit einem Schraegstrich
 * und ist fuer den Browser eine fremde Adresse. Eine Liste erlaubter Ziele
 * ist enger als jede Pruefung auf verbotene.
 */
const EINLADUNG = /^\/einladung\/[0-9a-f]{64}$/;

export function sichererWeiter(roh: string | null | undefined): string {
  return roh && EINLADUNG.test(roh) ? roh : "/";
}

export function einladungsPfad(token: string): string {
  return `/einladung/${token}`;
}
