import { notFound } from "next/navigation";
import { ladeKatalog } from "./catalog";

/**
 * Bereiche, die es im Gymtavo-Studio nicht gibt: Mitglieder, Kurse, Tags,
 * Geraete mit QR-Code (Spec 5.1, Waechter-Trigger aus 0047). Ein Aufruf
 * per URL endet auf 404 statt auf einer Seite, die so tut, als gaebe es sie.
 * Die Katalogpflege selbst kommt in Etappe 6.
 */
export async function nichtImKatalog(studioId: string): Promise<void> {
  const katalog = await ladeKatalog(studioId);
  if (katalog.isCatalog) notFound();
}
