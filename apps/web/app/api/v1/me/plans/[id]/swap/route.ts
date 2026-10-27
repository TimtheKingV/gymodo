import { z } from "zod";
import { requireUserId, tauschePlanPosition, type PlanTausch } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

type Context = { params: Promise<{ id: string }> };

// An der Systemgrenze pruefen: eine kaputte UUID kaeme sonst als rohe Postgres-Meldung zurueck.
const tauschSchema = z.object({
  einheitKey: z.string().min(1),
  positionKey: z.string().min(1),
  exerciseId: z.string().uuid(),
  modelId: z.string().uuid(),
  grund: z.enum(["nicht_vorhanden", "gefaellt_nicht"]).optional(),
  ortId: z.string().uuid().optional(),
});

/**
 * Tauscht eine Position des aktiven Plans dauerhaft; die Antwort ist die neue aktive
 * Version. Fremder oder nicht aktiver Plan: 409 (wie accept, damit fremde IDs nichts
 * verraten); ungueltige Position, Uebung oder Modell: 422. Mit `grund` kommt die alte
 * Uebung auf die Merkliste (ein Fehler dort bricht den Tausch nicht ab).
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
  const input = tauschSchema.safeParse(payload);
  if (!input.success) return errorResponse("validation_failed", "Der Tausch ist unvollstaendig oder ungueltig.");
  // exactOptionalPropertyTypes: fehlende Felder weglassen statt undefined zu uebergeben.
  const { grund, ortId, ...basis } = input.data;
  const tausch: PlanTausch = { ...basis, ...(grund ? { grund } : {}), ...(ortId ? { ortId } : {}) };
  try {
    const plan = await tauschePlanPosition(client, await requireUserId(client), id.data, tausch);
    return Response.json(plan, { status: 200 });
  } catch (error) {
    return fromDomainError(error);
  }
}
