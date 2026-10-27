// Ziele fuer Geraet und Abschluss laden (Etappe 4, Task 6; G17). Eigene Datei, weil
// plangewichte.ts den Bootstrap nicht importieren soll (der importiert plangewichte.ts).
import type { SupabaseClient } from "@supabase/supabase-js";
import { ladeZielgewichte, paarSchluessel, zielFuerGeraet, type PositionsZiel } from "./plangewichte.js";
import { ladeGezaehlteEinheiten } from "./trainingsplan-bootstrap.js";
import { naechsteEinheitKey } from "./trainingsplan-ablauf.js";
import { aktiverPlanImStudio } from "./trainingsplan.js";

/**
 * Das Ziel je Paar (Geraet, Uebung) aus dem aktiven Plan des Studios; Schluessel ist
 * paarSchluessel(machineId, exerciseId). Paare ohne Ziel fehlen im Ergebnis (dann gilt das
 * letzte Gewicht). Ohne aktiven Plan oder ohne Geraet (machineId null) ist es leer.
 * Liest nur; Fehler werden geworfen, der Aufrufer entscheidet.
 */
export async function ladeZieleFuerPaare(
  client: SupabaseClient,
  userId: string,
  studioId: string,
  paare: Array<{ machineId: string | null; exerciseId: string }>,
): Promise<Map<string, PositionsZiel>> {
  const ergebnis = new Map<string, PositionsZiel>();
  if (!paare.some((p) => p.machineId !== null)) return ergebnis;
  const plan = await aktiverPlanImStudio(client, userId, studioId);
  if (!plan || plan.einheiten.length === 0) return ergebnis;
  const [gezaehlt, ziele] = await Promise.all([
    ladeGezaehlteEinheiten(client, userId, plan.studioId, new Date()),
    ladeZielgewichte(client, userId, plan),
  ]);
  const naechste = naechsteEinheitKey(plan.einheiten.map((e) => e.key), gezaehlt.at(-1)?.einheitKey ?? null);
  for (const paar of paare) {
    if (paar.machineId === null) continue;
    const ziel = zielFuerGeraet(plan.einheiten, naechste, ziele, paar.machineId, paar.exerciseId);
    if (ziel) ergebnis.set(paarSchluessel(paar.machineId, paar.exerciseId), ziel);
  }
  return ergebnis;
}
