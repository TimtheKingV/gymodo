import { cache } from "react";
import { notFound, redirect } from "next/navigation";
import {
  DomainError,
  PHOTO_BUCKET,
  MEDIA_URL_TTL_SECONDS,
  getStudioCatalog,
  istAuthAusfall,
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
  // Ein Ausfall des Auth-Dienstes ist keine Aussage darueber, ob jemand
  // angemeldet ist. Ohne diese Unterscheidung landete ein 429, ein 5xx oder
  // ein abgerissener Aufruf als Sprung zum Login -- lautlos, ohne eine
  // Zeile im Protokoll, und von aussen nicht von einer abgelaufenen Sitzung
  // zu unterscheiden (derselbe Schnitt wie in PR #17). Ein ungueltiges oder
  // fehlendes Token bleibt, was es war: zum Login.
  const { data, error } = await client.auth.getUser();
  if (istAuthAusfall(error)) {
    console.error("Portal: Anmeldung liess sich nicht pruefen:", error);
    throw error;
  }
  if (!data.user) redirect("/login");

  let katalog: StudioCatalog;
  try {
    katalog = await getStudioCatalog(client, studioId);
  } catch (fehler) {
    // Nur "es gibt dieses Studio nicht" ist eine 404. Bis hierher fiel JEDER
    // DomainError auf notFound() -- ein Ausfall der Datenbank und eine
    // ungeprueft gebliebene Anmeldung lasen sich damit wortgleich als
    // "diese Seite gibt es nicht", und zwar ohne eine einzige Zeile im
    // Serverprotokoll. Genau dieser Weg macht einen Ausfall in der CI
    // unsichtbar: die Seite steht da, nur eben die falsche.
    if (fehler instanceof DomainError && fehler.code === "not_found") notFound();
    if (fehler instanceof DomainError && fehler.code === "unauthorized") {
      console.error("Portal: Katalog ohne gueltige Anmeldung:", fehler.message);
      redirect("/login");
    }
    if (fehler instanceof DomainError) {
      console.error(`Portal: Katalog nicht ladbar (${fehler.code}):`, fehler.message);
    }
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
