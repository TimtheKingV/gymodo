import { listCourseWeek } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

/**
 * Der Wochenplan eines Studios, screenorientiert (Spec 6.3): alles, was
 * member/Kurse.dc.html rendert, in einer Antwort -- Termine, Belegung als
 * Zahl und der eigene Buchungsstatus.
 *
 * Die Belegung kommt aus course_week (0037) und nicht aus einer Zaehlung
 * ueber Zeilen: ein Mitglied darf die Buchungen anderer nicht sehen.
 */
export async function GET(request: Request): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) {
    return errorResponse("unauthorized", "Anmeldung erforderlich.");
  }

  const parameter = new URL(request.url).searchParams;
  const studio = parameter.get("studio");
  if (!studio) {
    return errorResponse("validation_failed", "Der Parameter studio fehlt.");
  }

  // Vorgabe: die laufende Woche ab jetzt. Der Client darf ein eigenes
  // Fenster setzen; die Woche gehoert der Oberflaeche, nicht dem Vertrag.
  const jetzt = new Date();
  const von = parameter.get("from") ?? jetzt.toISOString();
  const bis =
    parameter.get("to") ?? new Date(jetzt.getTime() + 7 * 86_400_000).toISOString();

  try {
    const plan = await listCourseWeek(client, studio, von, bis);
    return Response.json(plan, {
      status: 200,
      headers: { "cache-control": "private, no-store" },
    });
  } catch (error) {
    return fromDomainError(error);
  }
}
