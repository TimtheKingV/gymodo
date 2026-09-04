import { z } from "zod";
import { listCourseWeek } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

/**
 * studio geht ungeprueft an PostgREST/course_week durch, sobald es den
 * Router verlaesst -- ein "?studio=abc" kaeme dort als
 * "invalid input syntax for type uuid" zurueck, courses.ts wickelt das
 * unveraendert in DomainError("internal", …) und respond.ts reicht die
 * Meldung wortwoertlich weiter (Finding 2 des Gesamtreviews). from/to
 * wurden bisher gar nicht geprueft. Hier, an der Systemgrenze, statt in
 * respond.ts -- das bleibt unangetastet.
 */
const parameterSchema = z.object({
  studio: z.string().uuid("Der Parameter studio ist keine gueltige UUID."),
  from: z
    .string()
    .datetime({ offset: true, message: "Der Parameter from ist kein gültiger Zeitpunkt." })
    .optional(),
  to: z
    .string()
    .datetime({ offset: true, message: "Der Parameter to ist kein gültiger Zeitpunkt." })
    .optional(),
});

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
  if (!parameter.get("studio")) {
    return errorResponse("validation_failed", "Der Parameter studio fehlt.");
  }

  const geprueft = parameterSchema.safeParse({
    studio: parameter.get("studio"),
    from: parameter.get("from") ?? undefined,
    to: parameter.get("to") ?? undefined,
  });
  if (!geprueft.success) {
    return errorResponse("validation_failed", geprueft.error.issues[0]!.message);
  }

  // Vorgabe: die laufende Woche ab jetzt. Der Client darf ein eigenes
  // Fenster setzen; die Woche gehoert der Oberflaeche, nicht dem Vertrag.
  const jetzt = new Date();
  const von = geprueft.data.from ?? jetzt.toISOString();
  const bis = geprueft.data.to ?? new Date(jetzt.getTime() + 7 * 86_400_000).toISOString();

  try {
    const plan = await listCourseWeek(client, geprueft.data.studio, von, bis);
    return Response.json(plan, {
      status: 200,
      headers: { "cache-control": "private, no-store" },
    });
  } catch (error) {
    return fromDomainError(error);
  }
}
