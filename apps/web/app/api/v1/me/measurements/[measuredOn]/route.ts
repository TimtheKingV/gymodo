import { deleteMeasurement } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

type Context = { params: Promise<{ measuredOn: string }> };

/**
 * Loescht den Eintrag eines Tages. Ein Tag ohne Eintrag ist danach genau
 * das -- kein 404, deshalb antwortet auch ein zweiter Aufruf mit 204.
 */
export async function DELETE(
  request: Request,
  { params }: Context,
): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) return errorResponse("unauthorized", "Anmeldung erforderlich.");
  try {
    await deleteMeasurement(client, (await params).measuredOn);
    return new Response(null, { status: 204 });
  } catch (error) {
    return fromDomainError(error);
  }
}
