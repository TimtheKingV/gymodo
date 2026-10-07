import type { SupabaseClient } from "@supabase/supabase-js";
import type { LoadUnit, VolumeKind } from "./belastung.js";
import { DomainError } from "./errors.js";

/** Eine Zeile aus my_history_labels() (Migration 0047, Abschnitt 5). */
export type Verlaufsname = {
  exercise_id: string;
  exercise_name: string;
  volume_kind: VolumeKind;
  equipment_model_id: string;
  model_name: string;
  load_unit: LoadUnit;
  secondary_unit: LoadUnit | null;
  machine_id: string | null;
  machine_label: string | null;
  studio_id: string;
  studio_name: string;
};

type Geraet = {
  label: string;
  equipment_models: { load_unit: LoadUnit; secondary_unit: LoadUnit | null };
};
type Uebung = { name: string; volume_kind: VolumeKind };

type SatzMitEinbettung = {
  machine_id: string | null;
  equipment_model_id: string;
  exercise_id: string;
  machines: Geraet | null;
  exercises: Uebung | null;
};

export type MitNamen<R extends SatzMitEinbettung> = Omit<R, "machines" | "exercises"> & {
  machines: Geraet;
  exercises: Uebung;
};

/**
 * Fuellt die Einbettungen, die RLS nach einem Austritt verschweigt.
 *
 * Seit 0047 gehoert der Verlauf dem Nutzer, der Katalog des verlassenen
 * Studios aber nicht mehr: die Saetze kommen, ihr Geraet und ihre Uebung
 * kommen als null. Lesbare Einbettungen gewinnen, weil sie den aktuellen
 * Namen tragen. Ohne Geraet traegt der Satz den Namen seines Geraetetyps --
 * das ist der Fall Freies Training und freie Gewichte.
 *
 * Eine Zeile ohne jeden Namen faellt weg. Das Verzeichnis entsteht aus
 * denselben eigenen Saetzen, eine Luecke hiesse also, dass der Satz
 * zwischen beiden Abfragen geloescht wurde.
 */
export function fuelleVerlaufsnamen<R extends SatzMitEinbettung>(
  zeilen: R[],
  namen: Verlaufsname[],
): MitNamen<R>[] {
  const uebungen = new Map<string, Uebung>();
  const geraete = new Map<string, Geraet>();
  const typen = new Map<string, Geraet>();
  for (const name of namen) {
    uebungen.set(name.exercise_id, { name: name.exercise_name, volume_kind: name.volume_kind });
    const einheiten = { load_unit: name.load_unit, secondary_unit: name.secondary_unit };
    if (name.machine_id && name.machine_label !== null) {
      geraete.set(name.machine_id, { label: name.machine_label, equipment_models: einheiten });
    }
    typen.set(name.equipment_model_id, { label: name.model_name, equipment_models: einheiten });
  }

  const ergebnis: MitNamen<R>[] = [];
  for (const zeile of zeilen) {
    const machines =
      zeile.machines ??
      (zeile.machine_id ? geraete.get(zeile.machine_id) : typen.get(zeile.equipment_model_id));
    const exercises = zeile.exercises ?? uebungen.get(zeile.exercise_id);
    if (!machines || !exercises) continue;
    ergebnis.push({ ...zeile, machines, exercises });
  }
  return ergebnis;
}

/**
 * Wie fuelleVerlaufsnamen, holt das Verzeichnis aber nur, wenn eine Luecke
 * da ist -- der Normalfall (nie ausgetreten) kostet keinen zweiten Aufruf.
 */
export async function mitVerlaufsnamen<R extends SatzMitEinbettung>(
  client: SupabaseClient,
  zeilen: R[],
): Promise<MitNamen<R>[]> {
  if (zeilen.every((zeile) => zeile.machines !== null && zeile.exercises !== null)) {
    return zeilen as unknown as MitNamen<R>[];
  }

  const { data, error } = await client.rpc("my_history_labels");
  if (error) {
    throw new DomainError("internal", error.message);
  }
  return fuelleVerlaufsnamen(zeilen, (data ?? []) as Verlaufsname[]);
}
