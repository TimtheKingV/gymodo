/**
 * Der Nummernvorschlag fuer ein neues Geraet.
 *
 * Ein Vorschlag, keine Vorschrift: machines.label ist frei (0007), und der
 * Entwurf sagt ausdruecklich, dass das Portal die Nummer nicht erzwingt --
 * am Geraet klebt womoeglich schon eine andere, und die gilt.
 */
export function naechsteGeraeteNummer(labels: string[]): string {
  const zahlen = labels
    .map((label) => label.trim())
    .filter((label) => /^\d+$/.test(label))
    .map(Number);
  const hoechste = zahlen.length === 0 ? 0 : Math.max(...zahlen);
  return String(hoechste + 1);
}
