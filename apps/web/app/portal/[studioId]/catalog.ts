import { cache } from "react";
import { notFound, redirect } from "next/navigation";
import {
  DomainError,
  PHOTO_BUCKET,
  MEDIA_URL_TTL_SECONDS,
  getStudioCatalog,
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
