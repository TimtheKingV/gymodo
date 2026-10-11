import { z } from "zod";

/**
 * Herkunft der Wiederholungszahl (Sensor-Spec B 2, 6.1-6.3).
 *
 * eingegeben: kein Zaehler lief oder er hat nichts gezaehlt.
 * gemessen:   der Zaehler stand beim Sichern auf genau diesem Wert.
 * korrigiert: der Zaehler stand anders, das Mitglied hat am Rad gedreht.
 */
export const volumeSourceSchema = z.enum(["eingegeben", "gemessen", "korrigiert"]);
export type VolumeSource = z.infer<typeof volumeSourceSchema>;

// Rohwerte wie Befestigungsart / UnsicherGrund im Swift-Package Sensorik.
export const befestigungsartSchema = z.enum([
  "stapel", "langhantel", "kurzhantel", "hebelarm", "kabelgriff", "koerper",
]);
export const unsicherGrundSchema = z.enum(["luecke", "signalSchwach", "taktUnregelmaessig"]);

const wiederholungSchema = z
  .object({
    beginn: z.number().min(0),
    umkehr: z.number().min(0),
    ende: z.number().min(0),
    ausschlag: z.number().min(0),
    sicherheit: z.number().min(0).max(1),
  })
  .refine((w) => w.beginn <= w.umkehr && w.umkehr <= w.ende, {
    message: "Eine Wiederholung braucht Beginn <= Umkehr <= Ende.",
  });

/**
 * rep_events (Spec B 6.2): nur, was sich nicht ableiten laesst. Zeiten in
 * Sekunden seit Satzbeginn.
 */
export const repEventsSchema = z.object({
  algo: z.string().min(1).max(64),
  befestigungsart: befestigungsartSchema,
  // Pflichtschluessel, auch als null: ein fehlender Schluessel waere eine
  // zweite Bedeutung von "nichts".
  unsicher: unsicherGrundSchema.nullable(),
  wiederholungen: z
    .array(wiederholungSchema)
    .min(1)
    .max(1000)
    .refine((liste) => liste.every((w, i) => i === 0 || liste[i - 1]!.beginn <= w.beginn), {
      message: "Die Wiederholungen muessen nach Beginn sortiert sein.",
    }),
});
export type RepEvents = z.infer<typeof repEventsSchema>;

/** Konsistenz aus Spec B 6.1; Fehlertext oder null. */
export function herkunftPruefen(v: {
  volume: number;
  volumeSource: VolumeSource;
  volumeCounted?: number | null | undefined;
  repEvents?: RepEvents | null | undefined;
}): string | null {
  const gezaehlt = v.volumeCounted ?? null;
  const events = v.repEvents ?? null;
  if (v.volumeSource === "eingegeben") {
    return gezaehlt === null && events === null
      ? null
      : "Ein eingegebener Satz traegt weder Zaehlerstand noch Ereignisse.";
  }
  if (gezaehlt === null || events === null) {
    return "Ein gezaehlter Satz braucht Zaehlerstand und Ereignisse.";
  }
  if (events.wiederholungen.length !== gezaehlt) {
    return "Die Zahl der Ereignisse passt nicht zum Zaehlerstand.";
  }
  if (v.volumeSource === "gemessen" && gezaehlt !== v.volume) {
    return "Ein gemessener Satz hat den Zaehlerstand als Umfang.";
  }
  if (v.volumeSource === "korrigiert" && gezaehlt === v.volume) {
    return "Ein korrigierter Satz weicht vom Zaehlerstand ab.";
  }
  return null;
}
