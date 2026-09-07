import { redirect } from "next/navigation";

/**
 * Geraetemodelle und Geraete sind ein Bereich (Struktur-Spec, Entscheidung
 * 5). Die Liste lebt unter /geraete; dieser Pfad bleibt als zweiter Name
 * bestehen -- er steht in Tests, in Links des Ueberblicks und vermutlich
 * in Lesezeichen. Eine Weiterleitung kostet vier Zeilen und bricht nichts.
 */
export default async function ModelleWeiterleitung({
  params,
}: {
  params: Promise<{ studioId: string }>;
}) {
  const { studioId } = await params;
  redirect(`/portal/${studioId}/geraete`);
}
