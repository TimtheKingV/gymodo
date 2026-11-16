import {
  addCardioCheck,
  deleteCardioCheck,
  deleteCardioCheckById,
  listCardioCheckEintraege,
  requireUserId,
  setCardioCheck,
} from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

const fehlt = (name: string): Response => errorResponse("validation_failed", `Der Parameter ${name} fehlt.`);

/** Obergrenze fuer Tage: morgen (UTC), damit jede Zeitzone durchkommt. */
const obergrenze = (): string => new Date(Date.now() + 86_400_000).toISOString().slice(0, 10);

/**
 * Die Cardio-Haken von `from` bis `to` (YYYY-MM-DD, eingeschlossen): `checks` mit id,
 * `days` als eindeutige Tage (Form der alten App).
 */
export async function GET(request: Request): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) return errorResponse("unauthorized", "Anmeldung erforderlich.");
  const params = new URL(request.url).searchParams;
  const from = params.get("from");
  const to = params.get("to");
  if (!from) return fehlt("from");
  if (!to) return fehlt("to");
  try {
    const checks = await listCardioCheckEintraege(client, await requireUserId(client), from, to);
    const days = [...new Set(checks.map((c) => c.day))];
    return Response.json({ checks, days }, { status: 200, headers: { "cache-control": "private, no-store" } });
  } catch (error) {
    return fromDomainError(error);
  }
}

/** Legt einen weiteren Haken an: Body `{day, minuten?}`, Antwort 201 mit dem Haken. */
export async function POST(request: Request): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) return errorResponse("unauthorized", "Anmeldung erforderlich.");
  let payload: unknown;
  try {
    payload = await request.json();
  } catch {
    return errorResponse("validation_failed", "Der Rumpf ist kein gueltiges JSON.");
  }
  const body = typeof payload === "object" && payload !== null ? (payload as Record<string, unknown>) : {};
  if (typeof body.day !== "string") return fehlt("day");
  if (body.minuten !== undefined && body.minuten !== null && typeof body.minuten !== "number") {
    return errorResponse("validation_failed", "Die Minuten muessen eine Zahl sein.");
  }
  try {
    const check = await addCardioCheck(client, await requireUserId(client), body.day, obergrenze(), body.minuten ?? undefined);
    return Response.json(check, { status: 201 });
  } catch (error) {
    return fromDomainError(error);
  }
}

/**
 * Hakt `day` ab (alter Weg, idempotent: legt nur an, wenn der Tag noch keinen Haken hat).
 * Die App sendet den Kalendertag des Mitglieds; der Server vertraut ihm und lehnt als
 * Netz nur Tage nach morgen (UTC) ab.
 */
export async function PUT(request: Request): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) return errorResponse("unauthorized", "Anmeldung erforderlich.");
  const day = new URL(request.url).searchParams.get("day");
  if (!day) return fehlt("day");
  try {
    await setCardioCheck(client, await requireUserId(client), day, obergrenze());
    return new Response(null, { status: 204 });
  } catch (error) {
    return fromDomainError(error);
  }
}

/** Nimmt das Abhaken zurueck: `?id` einen Haken, `?day` alle des Tages; Fehlendes antwortet ebenfalls 204. */
export async function DELETE(request: Request): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) return errorResponse("unauthorized", "Anmeldung erforderlich.");
  const params = new URL(request.url).searchParams;
  const id = params.get("id");
  const day = params.get("day");
  if (!id && !day) return fehlt("id");
  try {
    const userId = await requireUserId(client);
    if (id) await deleteCardioCheckById(client, userId, id);
    else if (day) await deleteCardioCheck(client, userId, day);
    return new Response(null, { status: 204 });
  } catch (error) {
    return fromDomainError(error);
  }
}
