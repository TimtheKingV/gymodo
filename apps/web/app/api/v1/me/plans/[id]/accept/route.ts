import { z } from "zod";
import { acceptPlan, requireUserId } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

type Context = { params: Promise<{ id: string }> };

/**
 * Nimmt einen Vorschlag an und ersetzt den aktiven Plan, atomar in
 * accept_training_plan. Fremder, verworfener oder schon aktiver Plan: 409 --
 * bewusst nicht 404 vs. 409 unterschieden, damit fremde IDs nichts verraten.
 */
export async function POST(request: Request, { params }: Context): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) return errorResponse("unauthorized", "Anmeldung erforderlich.");
  const id = z.string().uuid().safeParse((await params).id);
  if (!id.success) return errorResponse("validation_failed", "Die Plan-ID ist ungueltig.");
  try {
    const plan = await acceptPlan(client, await requireUserId(client), id.data);
    return Response.json(plan, { status: 200 });
  } catch (error) {
    return fromDomainError(error);
  }
}
