import { z } from "zod";
import { getEquipmentModelContext } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

type Context = { params: Promise<{ modelId: string }> };

const studioParam = z.string().uuid().optional();

/**
 * Der Kontext eines Gymtavo-Typs ohne Geraet -- Freies Training oder die
 * Langhantel im Studio, an der kein Sticker klebt (Spec 8.1).
 *
 * `?studio=` nennt den Ort, ohne ihn ist es das Gymtavo-Studio. Dieselbe
 * Antwortform wie machines/[machineId]/context, nur mit machine: null --
 * der Geraete-Screen soll fuer beide Faelle einer bleiben.
 */
export async function GET(
  request: Request,
  context: Context,
): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) {
    return errorResponse("unauthorized", "Anmeldung erforderlich.");
  }

  const studio = studioParam.safeParse(
    new URL(request.url).searchParams.get("studio") ?? undefined,
  );
  if (!studio.success) {
    return errorResponse("validation_failed", "Der Parameter studio ist keine gueltige UUID.");
  }

  const { modelId } = await context.params;

  try {
    const kontext = await getEquipmentModelContext(client, modelId, studio.data);
    return Response.json(kontext, {
      status: 200,
      // Persoenliche Werte und Historie: nie in einem geteilten Cache.
      headers: { "cache-control": "private, no-store" },
    });
  } catch (error) {
    return fromDomainError(error);
  }
}
