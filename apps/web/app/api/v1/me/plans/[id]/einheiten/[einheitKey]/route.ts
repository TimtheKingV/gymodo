import { z } from "zod";
import {
  ersetzePlanEinheit,
  requireUserId,
  type EinheitEingabePosition,
} from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

type Context = { params: Promise<{ id: string; einheitKey: string }> };

const ganz = z.number().int().optional();

const positionSchema = z.object({
  key: z.string().min(1).nullable(),
  exerciseId: z.string().uuid(),
  modelId: z.string().uuid(),
  saetze: ganz,
  wdhVon: ganz,
  wdhBis: ganz,
  pauseSek: ganz,
  dauerMin: ganz,
});

const ersetzenSchema = z.object({
  positionen: z.array(positionSchema).min(1).max(20),
});

/**
 * Speichert eine Einheit als Ganzes (Reihenfolge, Entfernen, Hinzufügen, Tauschen, Werte); Antwort ist
 * die neue aktive Version. Fremder oder nicht aktiver Plan: 409 (wie ordnen); ungültige Werte,
 * Übungen ohne Planmerkmale oder in gemiedenem Bereich: 422 (P4).
 */
export async function PUT(
  request: Request,
  { params }: Context,
): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) return errorResponse("unauthorized", "Anmeldung erforderlich.");
  const { id: rohId, einheitKey: rohKey } = await params;
  const id = z.string().uuid().safeParse(rohId);
  if (!id.success)
    return errorResponse("validation_failed", "Die Plan-ID ist ungültig.");
  const einheitKey = z.string().min(1).safeParse(rohKey);
  if (!einheitKey.success)
    return errorResponse("validation_failed", "Die Einheit ist ungültig.");
  let payload: unknown;
  try {
    payload = await request.json();
  } catch {
    return errorResponse(
      "validation_failed",
      "Der Rumpf ist kein gültiges JSON.",
    );
  }
  const input = ersetzenSchema.safeParse(payload);
  if (!input.success)
    return errorResponse(
      "validation_failed",
      "Die Einheit ist unvollständig oder ungültig.",
    );
  try {
    const plan = await ersetzePlanEinheit(
      client,
      await requireUserId(client),
      id.data,
      {
        einheitKey: einheitKey.data,
        // Fehlende Werte weglassen statt undefined zu senden (exactOptionalPropertyTypes).
        positionen: input.data.positionen.map(
          (p) =>
            Object.fromEntries(
              Object.entries(p).filter(([, v]) => v !== undefined),
            ) as EinheitEingabePosition,
        ),
      },
    );
    return Response.json(plan, { status: 200 });
  } catch (error) {
    return fromDomainError(error);
  }
}
