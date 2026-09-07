import { joinStudioByTag } from "@fitretro/domain";
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

  const tagToken =
    typeof payload === "object" && payload !== null && "tagToken" in payload
      ? String((payload as { tagToken: unknown }).tagToken)
      : "";

  try {
    const result = await joinStudioByTag(client, tagToken);
    return Response.json(
      { studioId: result.studioId, machineId: result.machineId, joined: result.joined },
      { status: 200 },
    );
  } catch (error) {
    return fromDomainError(error);
  }
}
