import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { requireUserId } from "./auth.js";
import { DomainError } from "./errors.js";
import { aktiveZiele, markiereErreicht } from "./goals.js";

/** Drei Jahre taeglich -- mehr liest niemand auf einem Telefon. */
const MEASUREMENT_LIMIT = 1000;

const datum = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "Datum im Format YYYY-MM-DD erwartet.");

export const messwertSchema = z.object({
  measuredOn: datum,
  weightKg: z
    .number()
    .min(20, "Das Gewicht liegt zwischen 20 und 400 kg.")
    .max(400, "Das Gewicht liegt zwischen 20 und 400 kg.")
    .refine((kg) => Math.round(kg * 10) === kg * 10, "Hoechstens eine Nachkommastelle."),
});

export type MesswertEingabe = z.infer<typeof messwertSchema>;

/**
 * `jetzt` als Parameter, damit die Zukunftsgrenze pruefbar ist. Ein Tag
 * Luft: der Client liefert seinen Ortstag, der Server vergleicht in UTC
 * -- ein Mitglied in Neuseeland darf "heute" eintragen, obwohl es in UTC
 * noch gestern ist.
 */
export function pruefeMesswert(roh: unknown, jetzt: Date = new Date()): MesswertEingabe {
  const geprueft = messwertSchema.safeParse(roh);
  if (!geprueft.success) {
    throw new DomainError("validation_failed", geprueft.error.issues[0]!.message);
  }
  const spaetestens = new Date(jetzt.getTime() + 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
  if (geprueft.data.measuredOn > spaetestens) {
    throw new DomainError("validation_failed", "Das Datum liegt in der Zukunft.");
  }
  return geprueft.data;
}

/**
 * Die Richtung ergibt sich aus dem ersten Messwert: lag der Start ueber
 * dem Ziel, gilt "<= Ziel" als erreicht, sonst ">= Ziel". Kein eigenes
 * Feld "abnehmen/zunehmen" -- es waere eine zweite Wahrheit neben den
 * Zahlen.
 */
export function zielErreicht(startKg: number | null, zielKg: number, neuKg: number): boolean {
  if (startKg === null) return false;
  return startKg >= zielKg ? neuKg <= zielKg : neuKg >= zielKg;
}

export type Messpunkt = { measuredOn: string; weightKg: number };

export type Measurements = {
  points: Messpunkt[];
  summary: {
    first: Messpunkt | null;
    latest: Messpunkt | null;
    /** latest - first. Kein Trend, keine Glaettung -- eine Differenz. */
    changeKg: number | null;
  };
};

export type RecordedMeasurement = Messpunkt & {
  /** true, wenn dieser Eintrag das aktive Zielgewicht erreicht hat. */
  goalReached: boolean;
};

export async function getMeasurements(
  client: SupabaseClient,
  rawOptions: unknown = {},
): Promise<Measurements> {
  const optionen = z.object({ since: datum.optional() }).safeParse(rawOptions);
  if (!optionen.success) {
    throw new DomainError("validation_failed", optionen.error.issues[0]!.message);
  }
  const userId = await requireUserId(client);

  // Absteigend gelesen und danach gedreht, nicht aufsteigend mit LIMIT:
  // so bleiben bei mehr als MEASUREMENT_LIMIT Eintraegen die NEUESTEN
  // erhalten und summary.latest bleibt der wahre juengste Wert, statt an
  // der Kappungsgrenze zu haengen.
  let query = client
    .from("body_measurements")
    .select("measured_on, weight_kg")
    .eq("user_id", userId)
    .order("measured_on", { ascending: false })
    .limit(MEASUREMENT_LIMIT);
  if (optionen.data.since) query = query.gte("measured_on", optionen.data.since);

  const { data, error } = await query;
  if (error) throw new DomainError("internal", "Der Gewichtsverlauf konnte nicht gelesen werden.");

  const points = ((data ?? []) as Array<{ measured_on: string; weight_kg: number | string }>)
    .map((row) => ({ measuredOn: row.measured_on, weightKg: Number(row.weight_kg) }))
    .reverse();
  const first = points[0] ?? null;
  const latest = points[points.length - 1] ?? null;
  return {
    points,
    summary: {
      first,
      latest,
      changeKg: first && latest ? Number((latest.weightKg - first.weightKg).toFixed(1)) : null,
    },
  };
}

/**
 * Ein Wert je Tag: der Upsert ersetzt, statt eine zweite Zeile anzulegen.
 *
 * "Ziel erreicht" wird HIER geprueft, beim Schreiben, nicht beim Lesen --
 * der Moment gehoert zu dem Eintrag, der ihn ausloest.
 */
export async function putMeasurement(
  client: SupabaseClient,
  payload: unknown,
): Promise<RecordedMeasurement> {
  const eingabe = pruefeMesswert(payload);
  const userId = await requireUserId(client);

  const { error } = await client
    .from("body_measurements")
    .upsert(
      { user_id: userId, measured_on: eingabe.measuredOn, weight_kg: eingabe.weightKg },
      { onConflict: "user_id,measured_on" },
    );
  if (error) throw new DomainError("internal", "Das Gewicht konnte nicht gespeichert werden.");

  // Bekannt und akzeptiert: Upsert und Markierung sind zwei Statements,
  // keine Transaktion. Scheitert die Markierung, steht der Messwert, und
  // der naechste Eintrag unter der Marke markiert nach. Ein RPC dafuer
  // waere eine dritte Funktion fuer einen Fall, der nur bei einem
  // Netzabbruch zwischen zwei Millisekunden entsteht.
  const ziele = await aktiveZiele(client, userId);
  let goalReached = false;
  if (ziele.targetWeight) {
    const { data: erster } = await client
      .from("body_measurements")
      .select("weight_kg")
      .eq("user_id", userId)
      .order("measured_on", { ascending: true })
      .limit(1)
      .maybeSingle();
    const startKg = erster ? Number((erster as { weight_kg: number | string }).weight_kg) : null;
    if (zielErreicht(startKg, ziele.targetWeight.targetValue, eingabe.weightKg)) {
      await markiereErreicht(client, ziele.targetWeight.id);
      goalReached = true;
    }
  }
  return { ...eingabe, goalReached };
}

export async function deleteMeasurement(client: SupabaseClient, measuredOnRoh: unknown): Promise<void> {
  const geprueft = datum.safeParse(measuredOnRoh);
  if (!geprueft.success) throw new DomainError("validation_failed", geprueft.error.issues[0]!.message);
  const userId = await requireUserId(client);

  const { error } = await client
    .from("body_measurements")
    .delete()
    .eq("user_id", userId)
    .eq("measured_on", geprueft.data);
  if (error) throw new DomainError("internal", "Der Eintrag konnte nicht geloescht werden.");
  // Ein Tag ohne Eintrag ist nach dem Loeschen genau das -- kein 404.
}
