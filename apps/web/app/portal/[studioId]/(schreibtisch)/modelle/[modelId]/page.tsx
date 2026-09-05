import { redirect } from "next/navigation";

/**
 * Wie modelle/page.tsx (Aufgabe 13): das Modell-Detail lebt seit Aufgabe 16
 * unter /geraete/<modelId>, aufgeteilt in vier Reiter (Struktur-Spec
 * Abschnitt 1, Entscheidung 5). Dieser Pfad bleibt als Weiterleitung
 * bestehen -- er steht in Tests, Links und vermutlich Lesezeichen. Eine
 * Weiterleitung kostet vier Zeilen und bricht nichts.
 */
export default async function ModellDetailWeiterleitung({
  params,
}: {
  params: Promise<{ studioId: string; modelId: string }>;
}) {
  const { studioId, modelId } = await params;
  redirect(`/portal/${studioId}/geraete/${modelId}`);
}
