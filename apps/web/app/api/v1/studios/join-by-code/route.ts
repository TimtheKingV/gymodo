import { joinStudioByCode } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

export async function POST(request: Request): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) return errorResponse("unauthorized", "Anmeldung erforderlich.");

  let payload: unknown;
  try {
    payload = await request.json();
  } catch {
    return errorResponse("validation_failed", "Der Rumpf ist kein gueltiges JSON.");
  }

  const code =
    typeof payload === "object" && payload !== null && "code" in payload
      ? String((payload as { code: unknown }).code)
      : "";

  try {
    const result = await joinStudioByCode(client, code);
    return Response.json(
      { studioId: result.studioId, joined: result.joined },
      { status: 200 },
    );
  } catch (error) {
    return fromDomainError(error);
  }
}
