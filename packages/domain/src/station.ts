/**
 * Wo ein Satz entstanden ist: an einem Geraet mit QR-Code oder, ohne ein
 * solches, an einem Geraetetyp (Langhantel im Studio, Freies Training).
 *
 * Seit 0047 traegt jeder Satz seinen Typ, das Geraet ist optional. Bloecke,
 * Historie und Vorschlaege hingen bis dahin an machine_id; sie haengen jetzt
 * an der Station, damit ein Satz ohne Geraet nicht mit allen anderen ohne
 * Geraet in einen Topf faellt.
 */
export type Station = { machineId: string | null; equipmentModelId: string };

/**
 * Das Praefix trennt die beiden Namensraeume: eine Geraete-id und eine
 * Typ-id sind beide UUIDs und koennten ohne es nicht unterschieden werden.
 */
export function stationsSchluessel(zeile: {
  machine_id: string | null;
  equipment_model_id: string;
}): string {
  return zeile.machine_id !== null
    ? `geraet:${zeile.machine_id}`
    : `typ:${zeile.equipment_model_id}`;
}
