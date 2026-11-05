// Ziele fuer Geraet und Abschluss laden (Etappe 4, Task 6; G17). Eigene Datei, weil
// plangewichte.ts den Bootstrap nicht importieren soll (der importiert plangewichte.ts).
import type { SupabaseClient } from "@supabase/supabase-js";
import {
  ladeZielgewichte,
  ohneAbbruch,
  uebungsSchluessel,
  zielFuerUebung,
  type Melde,
  type PositionsZiel,
} from "./plangewichte.js";
import { ladeGezaehlteEinheiten } from "./trainingsplan-bootstrap.js";
import { naechsteEinheitKey } from "./trainingsplan-ablauf.js";
import { aktiverKatalogPlan } from "./trainingsplan.js";

/**
 * Das Ziel je Uebung aus dem aktiven Plan; Schluessel ist uebungsSchluessel(exerciseId).
 * Das Gewicht haengt an der Uebung, nicht am Geraet (auch im Freien Training). Uebungen
 * ohne Ziel fehlen im Ergebnis (dann gilt das letzte Gewicht). Ohne aktiven Plan ist es
 * leer. Liest nur; Fehler werden geworfen, der Aufrufer entscheidet.
 */
export async function ladeZieleFuerPaare(
  client: SupabaseClient,
  userId: string,
  exerciseIds: string[],
): Promise<Map<string, PositionsZiel>> {
  const ergebnis = new Map<string, PositionsZiel>();
  if (exerciseIds.length === 0) return ergebnis;
  const plan = await aktiverKatalogPlan(client, userId);
  if (!plan || plan.einheiten.length === 0) return ergebnis;
  const [gezaehlt, ziele] = await Promise.all([
    ladeGezaehlteEinheiten(client, userId, new Date()),
    ladeZielgewichte(client, userId, plan),
  ]);
  const naechste = naechsteEinheitKey(plan.einheiten.map((e) => e.key), gezaehlt.at(-1)?.einheitKey ?? null);
  for (const exerciseId of new Set(exerciseIds)) {
    const ziel = zielFuerUebung(plan.einheiten, naechste, ziele, exerciseId);
    if (ziel) ergebnis.set(uebungsSchluessel(exerciseId), ziel);
  }
  return ergebnis;
}

/**
 * ladeZieleFuerPaare fuer Geraet und Abschluss, die daran nicht scheitern duerfen
 * (Final-Fix I4): ein Lesefehler (zu viele Statuszeilen, MAX_SATZSEITEN, plan_gewichte
 * fehlt, weil die API vor 0064 ausgeliefert wurde) wird wie bei ohneAbbruch protokolliert,
 * und es gilt "kein Ziel" -- also das letzte Gewicht. Sonst bricht der Geraete-Scan ab
 * bzw. completeSession antwortet 500, obwohl die Einheit schon beendet ist.
 */
export async function ladeZieleFuerPaareOhneAbbruch(
  client: SupabaseClient,
  userId: string,
  exerciseIds: string[],
  anlass: string,
  melde?: Melde,
): Promise<Map<string, PositionsZiel>> {
  let ziele = new Map<string, PositionsZiel>();
  await ohneAbbruch(
    anlass,
    async () => {
      ziele = await ladeZieleFuerPaare(client, userId, exerciseIds);
    },
    melde,
  );
  return ziele;
}
