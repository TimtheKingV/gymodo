/**
 * Der Name eines Geraets im Ueberblick (Testnotiz 25.09., #2).
 *
 * studio_overview liefert als `label` die Spalte machines.label -- die
 * Bezeichnung des einzelnen Geraets im Raum, meist eine Nummer. Allein
 * steht in "Gemeldete Probleme" dann "3", und niemand weiss, welches Geraet
 * gemeint ist. Der Typ steht im Katalog, den die Seite ohnehin laedt; ein
 * Umbau des RPC (und damit eine Migration) waere fuer denselben Namen
 * teurer. Dasselbe Muster wie einrichten/geraet/[machineId]:
 * "Beinpresse 3".
 *
 * Steht das Geraet nicht im Katalog, bleibt die Bezeichnung allein -- eine
 * Luecke darf die Zeile nicht kosten.
 */
export function geraeteName(
  katalog: { models: { name: string; machines: { id: string }[] }[] },
  machineId: string,
  label: string,
): string {
  const modell = katalog.models.find((eintrag) =>
    eintrag.machines.some((geraet) => geraet.id === machineId),
  );
  return modell ? `${modell.name} ${label}` : label;
}
