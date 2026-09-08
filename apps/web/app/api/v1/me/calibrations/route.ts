import { recordCalibration } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

/**
 * Eigene Einstellwerte schreiben (Kalibrierung).
 *
 * Ausserhalb der sechs Endpoints aus M1-Spec SS6.3 -- wie schon
 * studios/join-by-code, join-by-tag und DELETE membership aus
 * Sub-Projekt 1. Die Architekturaussage dahinter (screenorientiert, keine
 * Fachlogik im Client) bleibt unberuehrt.
 */
export async function POST(request: Request): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) return errorResponse("unauthorized", "Anmeldung erforderlich.");

  let payload: unknown;
  try {
    payload = await request.json();
  } catch {
    return errorResponse("validation_failed", "Der Rumpf ist kein gueltiges JSON.");
  }

  try {
    const calibration = await recordCalibration(client, payload);
    return Response.json(calibration, { status: 201 });
  } catch (error) {
    return fromDomainError(error);
  }
}
