import { cache } from "react";
import { notFound, redirect } from "next/navigation";
import {
  DomainError,
  PHOTO_BUCKET,
  MEDIA_URL_TTL_SECONDS,
  getStudioCatalog,
  listStudioMembers,
  signMediaUrls,
  type StudioCatalog,
} from "@fitretro/domain";
import { createServerSupabaseClient } from "@/lib/supabase/server";

/**
 * Der Katalog wird je Anfrage einmal geladen -- die Rail und der Inhalt
 * brauchen ihn beide, und React deduziert den Aufruf ueber cache().
 *
 * Die Fotopfade werden hier zu signierten URLs: der Bucket ist privat, ein
 * img-Tag kann mit einem Speicherpfad nichts anfangen.
 */
export type PortalCatalog = StudioCatalog & {
  photoUrls: Record<string, string>;
};

export const ladeKatalog = cache(async (studioId: string): Promise<PortalCatalog> => {
  const client = await createServerSupabaseClient();
  const {
    data: { user },
  } = await client.auth.getUser();
  if (!user) redirect("/login");

  let katalog: StudioCatalog;
  try {
    katalog = await getStudioCatalog(client, studioId);
  } catch (fehler) {
    if (fehler instanceof DomainError) notFound();
    throw fehler;
  }

  const pfade = katalog.models
    .map((modell) => modell.photoPath)
    .filter((pfad): pfad is string => Boolean(pfad));
  const signiert = await signMediaUrls(
    client,
    PHOTO_BUCKET,
    pfade,
    MEDIA_URL_TTL_SECONDS,
  );

  return { ...katalog, photoUrls: Object.fromEntries(signiert) };
});

/** Wie viele Geraete eines Modells fuer Mitglieder erreichbar sind. */
export function erreichbarkeit(modell: StudioCatalog["models"][number]): {
  geraete: number;
  erreichbar: number;
} {
  const aktive = modell.machines.filter((geraet) => geraet.status === "active");
  return {
    geraete: aktive.length,
    erreichbar: aktive.filter((geraet) => geraet.activeTagCount > 0).length,
  };
}

export type RailZahlen = {
  geraete: number;
  erreichbar: number;
  vorrat: number;
  /** null heisst "darf ich nicht wissen", nicht "keine". */
  mitglieder: number | null;
  mitarbeiter: number | null;
};

/**
 * Die Zahlen der Rail an einer Stelle -- sie stehen auf jeder Seite und
 * duerfen deshalb nirgends eine Seite kosten.
 *
 * mitglieder/mitarbeiter sind `null`, wenn das Konto sie nicht sehen darf:
 * listStudioMembers wirft fuer ein einfaches Mitglied "unauthorized". Das
 * ist kein Fehler, sondern die Datenschutzgrenze -- und ohne dieses
 * Abfangen faellt die Navigation JEDER Seite gleichzeitig aus, nicht nur
 * die Zahl.
 *
 * `null` heisst "darf ich nicht wissen", nicht "keine". Die Rail zeigt
 * dann keine Zeile statt einer 0.
 */
export const railZahlen = cache(async (studioId: string): Promise<RailZahlen> => {
  const katalog = await ladeKatalog(studioId);
  const client = await createServerSupabaseClient();

  const summe = katalog.models.reduce(
    (stand, modell) => {
      const { geraete, erreichbar } = erreichbarkeit(modell);
      return { geraete: stand.geraete + geraete, erreichbar: stand.erreichbar + erreichbar };
    },
    { geraete: 0, erreichbar: 0 },
  );

  let mitglieder: number | null = null;
  let mitarbeiter: number | null = null;
  try {
    const leute = await listStudioMembers(client, studioId);
    mitglieder = leute.filter((person) => person.role === "member").length;
    mitarbeiter = leute.length - mitglieder;
  } catch (fehler) {
    if (!(fehler instanceof DomainError && fehler.code === "unauthorized")) throw fehler;
  }

  return {
    ...summe,
    vorrat: katalog.tags.filter((tag) => tag.status === "unassigned").length,
    mitglieder,
    mitarbeiter,
  };
});
