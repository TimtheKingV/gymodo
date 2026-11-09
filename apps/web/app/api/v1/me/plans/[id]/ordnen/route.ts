import { z } from "zod";
import { ordnePlanEinheit, requireUserId } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

type Context = { params: Promise<{ id: string }> };

const ordnenSchema = z.object({
  einheitKey: z.string().min(1),
  positionKeys: z.array(z.string().min(1)).min(1).max(20),
});

/**
 * Ordnet die Positionen einer Einheit neu; fehlende Schluessel werden entfernt. Antwort ist
 * die neue aktive Version. Fremder oder nicht aktiver Plan: 409 (wie swap, damit fremde IDs
 * nichts verraten); leere, doppelte oder unbekannte Schluessel: 422.
 */
export async function POST(request: Request, { params }: Context): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) return errorResponse("unauthorized", "Anmeldung erforderlich.");
  const id = z.string().uuid().safeParse((await params).id);
  if (!id.success) return errorResponse("validation_failed", "Die Plan-ID ist ungueltig.");
  let payload: unknown;
  try {
    payload = await request.json();
  } catch {
    return errorResponse("validation_failed", "Der Rumpf ist kein gueltiges JSON.");
  }
  const input = ordnenSchema.safeParse(payload);
  if (!input.success) return errorResponse("validation_failed", "Die Reihenfolge ist unvollständig oder ungültig.");
  try {
    const plan = await ordnePlanEinheit(client, await requireUserId(client), id.data, input.data);
    return Response.json(plan, { status: 200 });
  } catch (error) {
    return fromDomainError(error);
  }
}
