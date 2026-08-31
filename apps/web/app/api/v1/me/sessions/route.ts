import { getSessions } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

/**
 * Der Trainingsverlauf fuer den Home-Tab, einschliesslich Session-Detail.
 *
 * Dieser Lesezugriff schliesst nebenbei vergessene Einheiten ab (Spec 5.2):
 * der traege Autoabschluss braucht keinen Cronjob, weil er hier entsteht.
 */
export async function GET(request: Request): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) {
    return errorResponse("unauthorized", "Anmeldung erforderlich.");
  }

  try {
    const sessions = await getSessions(client);
    return Response.json(sessions, {
      status: 200,
      headers: { "cache-control": "private, no-store" },
    });
  } catch (error) {
    return fromDomainError(error);
  }
}
