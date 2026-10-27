import { z } from "zod";
import { requireUserId, tauschePlanPosition } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

type Context = { params: Promise<{ id: string }> };

// An der Systemgrenze pruefen: eine kaputte UUID kaeme sonst als rohe Postgres-Meldung zurueck.
const tauschSchema = z.object({
  einheitKey: z.string().min(1),
  positionKey: z.string().min(1),
  exerciseId: z.string().uuid(),
  machineId: z.string().uuid(),
});

/**
 * Tauscht eine Position des aktiven Plans dauerhaft; die Antwort ist die neue aktive
 * Version. Fremder oder nicht aktiver Plan: 409 (wie accept, damit fremde IDs nichts
 * verraten); ungueltige Position, Uebung oder Geraet: 422.
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
  try {
    const plan = await tauschePlanPosition(client, await requireUserId(client), id.data, input.data);
    return Response.json(plan, { status: 200 });
  } catch (error) {
    return fromDomainError(error);
  }
}
