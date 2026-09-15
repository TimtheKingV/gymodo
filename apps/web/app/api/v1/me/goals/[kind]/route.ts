import { dropGoal } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

type Context = { params: Promise<{ kind: string }> };

/**
 * Ein Ziel aufgeben. Kein aktives Ziel dieser Sorte ist kein Fehler --
 * auch ein zweiter Aufruf antwortet 204, wie beim Loeschen eines Messwerts.
 */
export async function DELETE(
  request: Request,
  { params }: Context,
): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) return errorResponse("unauthorized", "Anmeldung erforderlich.");
  try {
    await dropGoal(client, (await params).kind);
    return new Response(null, { status: 204 });
  } catch (error) {
    return fromDomainError(error);
  }
}
