import { z } from "zod";
import type { VolumeKind } from "./belastung.js";

/**
 * Kameraprofil und Tempo einer Uebung (Plan 2026-11-24-kamera-tempo-kern-katalog,
 * Task 8/9; Migration 0077). Die Regeln in kameraFehler sind dieselben wie die
 * Constraints der Datenbank, damit der Import nie eine Zeile schreibt, an der
 * sie scheitert.
 */

export const KAMERA_PROFILE = ["ganzkoerper_stehend", "oberkoerper", "stuetz_boden", "liegend", "zug_haengend", "ohne_kamera"] as const;
export const KAMERA_SIGNALE = ["ellbogen", "schulter", "huefte", "knie"] as const;
export const KAMERA_SEITEN = ["links", "rechts", "beide"] as const;
export const TEMPO_BEGINN = ["senken", "heben"] as const;

export type KameraProfil = (typeof KAMERA_PROFILE)[number];
export type KameraSignal = (typeof KAMERA_SIGNALE)[number];
export type KameraSeite = (typeof KAMERA_SEITEN)[number];
export type TempoBeginn = (typeof TEMPO_BEGINN)[number];

/** Profile, die der Katalog schon vergeben darf; die uebrigen warten auf ihre Kameraerkennung. */
export const FREIGESCHALTETE_PROFILE: readonly KameraProfil[] = ["ohne_kamera"];

export type UebungKamera = { profil: KameraProfil; signal: KameraSignal | null; seite: KameraSeite | null; beginntMit: TempoBeginn };
export type UebungTempo = { senkenS: number; haltenS: number; hebenS: number };

const raster = (n: number) => Math.abs(n * 2 - Math.round(n * 2)) < 1e-6;
const tempoZeit = (min: number, max: number) =>
  z
    .number()
    .min(min, `muss mindestens ${min} sein`)
    .max(max, `darf hoechstens ${max} sein`)
    .refine(raster, "muss ein Vielfaches von 0,5 sein");

export const kameraDateiSchema = z
  .object({
    profil: z.enum(KAMERA_PROFILE),
    signal: z.enum(KAMERA_SIGNALE).nullable().default(null),
    seite: z.enum(KAMERA_SEITEN).default("beide"),
    beginnt_mit: z.enum(TEMPO_BEGINN),
  })
  .strict();

export const tempoDateiSchema = z
  .object({
    senken_s: tempoZeit(1, 4),
    halten_s: tempoZeit(0, 3),
    heben_s: tempoZeit(1, 4),
  })
  .strict();

export type KameraDatei = z.infer<typeof kameraDateiSchema>;
export type TempoDatei = z.infer<typeof tempoDateiSchema>;

export function kameraFehler(
  k: KameraDatei | undefined,
  tempo: TempoDatei | undefined,
  volumeKind: VolumeKind,
  opts: { nurFreigeschaltet: boolean },
): string[] {
  const fehler: string[] = [];
  if (k === undefined) {
    if (tempo !== undefined) fehler.push("tempo nur zusammen mit kamera");
    return fehler;
  }
  if (volumeKind !== "reps") fehler.push(`kamera nur bei volume_kind "reps", ist "${volumeKind}"`);
  if (k.profil === "ohne_kamera") {
    if (k.signal !== null) fehler.push('kamera.signal muss bei profil "ohne_kamera" null sein');
  } else if (k.signal === null) {
    fehler.push(`kamera.signal fehlt (Pflicht bei profil "${k.profil}")`);
  }
  if (opts.nurFreigeschaltet && !FREIGESCHALTETE_PROFILE.includes(k.profil)) {
    fehler.push(`kamera.profil "${k.profil}" ist noch nicht freigeschaltet (erlaubt: ${FREIGESCHALTETE_PROFILE.join(", ")})`);
  }
  return fehler;
}

export type KameraSpalten = {
  kamera_profil: KameraProfil | null;
  kamera_signal: KameraSignal | null;
  kamera_seite: KameraSeite | null;
  tempo_senken_s: number | null;
  tempo_halten_s: number | null;
  tempo_heben_s: number | null;
  tempo_beginnt_mit: TempoBeginn | null;
};

export function kameraSpalten(k: KameraDatei | undefined, tempo: TempoDatei | undefined): KameraSpalten {
  if (k === undefined) {
    return { kamera_profil: null, kamera_signal: null, kamera_seite: null, tempo_senken_s: null, tempo_halten_s: null, tempo_heben_s: null, tempo_beginnt_mit: null };
  }
  const mitSignal = k.profil !== "ohne_kamera";
  return {
    kamera_profil: k.profil,
    kamera_signal: mitSignal ? k.signal : null,
    kamera_seite: mitSignal ? k.seite : null,
    tempo_senken_s: tempo?.senken_s ?? null,
    tempo_halten_s: tempo?.halten_s ?? null,
    tempo_heben_s: tempo?.heben_s ?? null,
    tempo_beginnt_mit: k.beginnt_mit,
  };
}

type Zahl = number | string | null;
export type KameraZeile = {
  kamera_profil: string | null;
  kamera_signal: string | null;
  kamera_seite: string | null;
  tempo_senken_s: Zahl;
  tempo_halten_s: Zahl;
  tempo_heben_s: Zahl;
  tempo_beginnt_mit: string | null;
};

/** Die sieben Spalten sind in Zeilen aelterer Herkunft (und alten Testdaten) nicht da; fehlend heisst null. */
export type KameraZeileOptional = Partial<KameraZeile>;

export function kameraAusZeile(z: KameraZeileOptional): { kamera: UebungKamera | null; tempo: UebungTempo | null } {
  const kamera: UebungKamera | null =
    z.kamera_profil == null
      ? null
      : {
          profil: z.kamera_profil as KameraProfil,
          signal: (z.kamera_signal ?? null) as KameraSignal | null,
          seite: (z.kamera_seite ?? null) as KameraSeite | null,
          beginntMit: (z.tempo_beginnt_mit ?? "heben") as TempoBeginn,
        };
  const tempo: UebungTempo | null =
    z.tempo_senken_s == null || z.tempo_halten_s == null || z.tempo_heben_s == null
      ? null
      : { senkenS: Number(z.tempo_senken_s), haltenS: Number(z.tempo_halten_s), hebenS: Number(z.tempo_heben_s) };
  return { kamera, tempo };
}
