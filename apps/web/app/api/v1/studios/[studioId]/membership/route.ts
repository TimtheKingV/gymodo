import { leaveStudio } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

type Context = { params: Promise<{ studioId: string }> };

export async function DELETE(request: Request, context: Context): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) return errorResponse("unauthorized", "Anmeldung erforderlich.");

  const { studioId } = await context.params;

  try {
    await leaveStudio(client, studioId);
    return new Response(null, { status: 204 });
  } catch (error) {
    return fromDomainError(error);
  }
}
