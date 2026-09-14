import { getMeasurements, putMeasurement } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

/**
 * Der Gewichtsverlauf (Spec 3.2). Ein Wert je Tag, keine Aggregation --
 * anders als /me/progress ist das hier die Rohreihe, sie ist klein genug.
 */
export async function GET(request: Request): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) {
    return errorResponse("unauthorized", "Anmeldung erforderlich.");
  }

  const since = new URL(request.url).searchParams.get("since");

  try {
    const measurements = await getMeasurements(client, since ? { since } : {});
    return Response.json(measurements, {
      status: 200,
      headers: { "cache-control": "private, no-store" },
    });
  } catch (error) {
    return fromDomainError(error);
  }
}

/**
 * Ein Gewicht fuer einen Tag eintragen oder korrigieren.
 *
 * PUT, nicht POST: der Upsert auf (user_id, measured_on) macht denselben
 * Aufruf zweimal gesendet zu demselben Eintrag -- dasselbe Muster wie
 * beim Profil und beim Satz-Schreibweg.
 */
export async function PUT(request: Request): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) return errorResponse("unauthorized", "Anmeldung erforderlich.");

  let payload: unknown;
  try {
    payload = await request.json();
  } catch {
    return errorResponse("validation_failed", "Der Rumpf ist kein gueltiges JSON.");
  }

  try {
    const messwert = await putMeasurement(client, payload);
    return Response.json(messwert, { status: 200 });
  } catch (error) {
    return fromDomainError(error);
  }
}
