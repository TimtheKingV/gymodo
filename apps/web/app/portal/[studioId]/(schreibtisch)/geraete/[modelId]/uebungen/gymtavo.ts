import type { CatalogModel, CatalogType } from "@fitretro/domain";
import type { VolumeKind } from "@fitretro/domain/belastung";

/**
 * Was der Reiter Uebungen unter "Gymtavo-Übungen" zeigt -- eine reine
 * Ableitung aus Studio-Katalog und Typliste, ohne Datenbank und ohne React
 * (Muster wie offen.ts nebenan). Die App mischt dieselben Quellen
 * (Spec 8.1); hier steht, was der Trainer davon sieht.
 */
export type Video = { storagePath: string; durationS: number | null };

export type GymtavoZeileDaten = {
  exerciseId: string;
  name: string;
  volumeKind: VolumeKind;
  targetMin: number;
  targetMax: number;
  herkunft: "typ" | "angehaengt";
  /** Verknuepfung am Studio-Modell -- nur sie traegt ein eigenes Video. */
  linkId: string | null;
  eigenesVideo: Video | null;
  katalogVideo: Video | null;
};

type Modell = Pick<CatalogModel, "catalogModelId" | "exercises">;

function katalogVideos(typen: CatalogType[]): Map<string, Video> {
  const videos = new Map<string, Video>();
  for (const typ of typen) {
    for (const uebung of typ.exercises) {
      if (uebung.videoStoragePath && !videos.has(uebung.exerciseId)) {
        videos.set(uebung.exerciseId, {
          storagePath: uebung.videoStoragePath,
          durationS: uebung.videoDurationS,
        });
      }
    }
  }
  return videos;
}

export function gymtavoZeilen(modell: Modell, typen: CatalogType[]): GymtavoZeileDaten[] {
  const videos = katalogVideos(typen);
  const verknuepft = new Map(
    modell.exercises.filter((u) => u.fromCatalog).map((u) => [u.exerciseId, u]),
  );
  const typ = typen.find((eintrag) => eintrag.id === modell.catalogModelId);

  function eigenesVideo(exerciseId: string): Video | null {
    const link = verknuepft.get(exerciseId);
    return link?.videoStoragePath
      ? { storagePath: link.videoStoragePath, durationS: link.videoDurationS }
      : null;
  }

  const vomTyp: GymtavoZeileDaten[] = (typ?.exercises ?? []).map((uebung) => ({
    exerciseId: uebung.exerciseId,
    name: uebung.name,
    volumeKind: uebung.volumeKind,
    targetMin: uebung.targetMin,
    targetMax: uebung.targetMax,
    herkunft: "typ",
    linkId: verknuepft.get(uebung.exerciseId)?.linkId ?? null,
    eigenesVideo: eigenesVideo(uebung.exerciseId),
    katalogVideo: videos.get(uebung.exerciseId) ?? null,
  }));

  const amTyp = new Set(vomTyp.map((zeile) => zeile.exerciseId));
  const angehaengt: GymtavoZeileDaten[] = [...verknuepft.values()]
    .filter((link) => !amTyp.has(link.exerciseId))
    .map((link) => ({
      exerciseId: link.exerciseId,
      name: link.name,
      volumeKind: link.volumeKind,
      targetMin: link.targetMin,
      targetMax: link.targetMax,
      herkunft: "angehaengt",
      linkId: link.linkId,
      eigenesVideo: eigenesVideo(link.exerciseId),
      katalogVideo: videos.get(link.exerciseId) ?? null,
    }));

  return [...vomTyp, ...angehaengt];
}

export function eigeneUebungen<T extends { fromCatalog: boolean }>(uebungen: T[]): T[] {
  return uebungen.filter((uebung) => !uebung.fromCatalog);
}

export function anhaengbareUebungen(
  modell: Modell,
  typen: CatalogType[],
): { exerciseId: string; name: string; typName: string }[] {
  const gezeigt = new Set(gymtavoZeilen(modell, typen).map((zeile) => zeile.exerciseId));
  const angebot = new Map<string, { exerciseId: string; name: string; typName: string }>();
  for (const typ of typen) {
    for (const uebung of typ.exercises) {
      if (gezeigt.has(uebung.exerciseId) || angebot.has(uebung.exerciseId)) continue;
      angebot.set(uebung.exerciseId, {
        exerciseId: uebung.exerciseId,
        name: uebung.name,
        typName: typ.name,
      });
    }
  }
  return [...angebot.values()].sort((a, b) => a.name.localeCompare(b.name, "de"));
}
