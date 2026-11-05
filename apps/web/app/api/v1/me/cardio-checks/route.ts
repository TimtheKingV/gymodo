import { deleteCardioCheck, listCardioChecks, requireUserId, setCardioCheck } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

const fehlt = (name: string): Response => errorResponse("validation_failed", `Der Parameter ${name} fehlt.`);

/** Die abgehakten Cardio-Tage von `from` bis `to` (YYYY-MM-DD, eingeschlossen). */
export async function GET(request: Request): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) return errorResponse("unauthorized", "Anmeldung erforderlich.");
  const params = new URL(request.url).searchParams;
  const from = params.get("from");
  const to = params.get("to");
  if (!from) return fehlt("from");
  if (!to) return fehlt("to");
  try {
    const days = await listCardioChecks(client, await requireUserId(client), from, to);
    return Response.json({ days }, { status: 200, headers: { "cache-control": "private, no-store" } });
  } catch (error) {
    return fromDomainError(error);
  }
}

/**
 * Hakt `day` ab. Die App sendet den Kalendertag des Mitglieds; der Server
 * vertraut ihm und lehnt als Netz nur Tage nach morgen (UTC) ab, damit jede
 * Zeitzone durchkommt.
 */
export async function PUT(request: Request): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) return errorResponse("unauthorized", "Anmeldung erforderlich.");
  const day = new URL(request.url).searchParams.get("day");
  if (!day) return fehlt("day");
  try {
    const obergrenze = new Date(Date.now() + 86_400_000).toISOString().slice(0, 10);
    await setCardioCheck(client, await requireUserId(client), day, obergrenze);
    return new Response(null, { status: 204 });
  } catch (error) {
    return fromDomainError(error);
  }
}

/** Nimmt das Abhaken zurueck; ein fehlender Tag antwortet ebenfalls 204. */
export async function DELETE(request: Request): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) return errorResponse("unauthorized", "Anmeldung erforderlich.");
  const day = new URL(request.url).searchParams.get("day");
  if (!day) return fehlt("day");
  try {
    await deleteCardioCheck(client, await requireUserId(client), day);
    return new Response(null, { status: 204 });
  } catch (error) {
    return fromDomainError(error);
  }
}
