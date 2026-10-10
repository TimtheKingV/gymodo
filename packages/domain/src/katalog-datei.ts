import { z } from "zod";
import { CATEGORIES, LOAD_UNITS, MAX_VOLUME, VOLUME_KINDS } from "./belastung.js";
import { MAX_VIDEO_SECONDS } from "./media.js";

/**
 * Das Format von catalog/gymtavo.json und seine Pruefung.
 *
 * Spec 2026-10-06-gymtavo-katalog-offener-zugang-design.md, Abschnitt 9.1.
 * Die Datei ist die gepflegte Quelle des Gymtavo-Katalogs; geschrieben wird
 * nur, was hier durchgeht. Alle Fehler kommen auf einmal, sonst wird eine
 * Datei mit 162 Uebungen in Dutzenden Laeufen repariert. Jede Meldung nennt
 * Index und Schluessel, weil eine Zeilennummer in einer 6000-Zeilen-Datei
 * niemandem hilft.
 *
 * Objekte sind strict: ein vertippter Feldname soll auffallen, statt still
 * ignoriert zu werden und als fehlender Wert zu enden.
 */

/** Feste id aus Migration 0047. */
export const GYMTAVO_STUDIO_ID = "00000000-0000-4000-8000-000000000001";

export const GRIFFE = [
  "neutral",
  "pronated",
  "supinated",
  "semi_pronated",
  "semi_supinated",
  "rotating",
  "front_rack",
  "none",
] as const;

const schluessel = z.string().regex(/^[a-z0-9_]+$/, "darf nur a-z, 0-9 und _ enthalten");
const text = z.string().trim().min(1, "darf nicht leer sein");
const positiv = z.number().positive("muss groesser als 0 sein");
const nichtNegativ = z.number().nonnegative("darf nicht negativ sein");
const ganzPositiv = z.number().int("muss eine ganze Zahl sein").positive("muss groesser als 0 sein");

// Ein Medienpfad, der aus dem Katalogordner hinausfuehrt, wuerde beliebige
// Dateien des Rechners hochladen, auf dem das Skript laeuft.
const medienPfad = z
  .string()
  .trim()
  .min(1, "darf nicht leer sein")
  .refine(
    (pfad) => !pfad.startsWith("/") && !pfad.split("/").includes(".."),
    "muss relativ zur Datei sein und darf nicht mit .. hinausfuehren",
  );

const einstellungSchema = z.discriminatedUnion("kind", [
  z
    .object({
      key: schluessel,
      label: text,
      kind: z.literal("number"),
      min: z.number().nullable(),
      max: z.number().nullable(),
      step: positiv.nullable(),
      unit: text.nullable(),
    })
    .strict(),
  z
    .object({
      key: schluessel,
      label: text,
      kind: z.literal("enum"),
      allowed_values: z.array(text).min(2, "braucht mindestens zwei Werte"),
    })
    .strict(),
]);

const geraetetypSchema = z
  .object({
    key: schluessel,
    name: text,
    category: z.enum(CATEGORIES),
    manufacturer: text.nullable(),
    photo: medienPfad.nullable(),
    load_unit: z.enum(LOAD_UNITS),
    load_step: positiv,
    load_min: nichtNegativ,
    load_max: nichtNegativ.nullable(),
    // Alle vier oder keiner: so verlangt es equipment_models_secondary_all_or_none (0046).
    secondary: z
      .object({ unit: z.enum(LOAD_UNITS), step: positiv, min: nichtNegativ, max: nichtNegativ })
      .strict()
      .nullable(),
    settings: z.array(einstellungSchema),
    exercises: z.array(schluessel),
  })
  .strict();

const uebungSchema = z
  .object({
    key: schluessel,
    name: text,
    description: text.nullable(),
    volume_kind: z.enum(VOLUME_KINDS),
    target_min: ganzPositiv,
    target_max: ganzPositiv,
    video: z
      .object({
        file: medienPfad,
        duration_s: z
          .number()
          .int("muss eine ganze Zahl sein")
          .min(1, "muss mindestens 1 sein")
          .max(MAX_VIDEO_SECONDS, `darf hoechstens ${MAX_VIDEO_SECONDS} sein`),
      })
      .strict()
      .nullable(),
    grip: z.enum(GRIFFE).nullable(),
    muscles: z.array(z.object({ muscle: schluessel, role: z.enum(["primary", "secondary"]) }).strict()),
    review: z.enum(["draft", "reviewed"]),
    sources: z.array(schluessel),
  })
  .strict();

const katalogSchema = z
  .object({
    format: z.literal(1),
    muscles: z.array(z.object({ key: schluessel, name: text }).strict()),
    sources: z.array(
      z
        .object({
          key: schluessel,
          title: text,
          url: z.string().regex(/^https:\/\/\S+$/, "muss eine https-Adresse sein"),
          accessed_at: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "muss ein Datum JJJJ-MM-TT sein"),
        })
        .strict(),
    ),
    equipment: z.array(geraetetypSchema),
    exercises: z.array(uebungSchema),
  })
  .strict();

export type KatalogDatei = z.infer<typeof katalogSchema>;
export type Geraetetyp = KatalogDatei["equipment"][number];
export type Uebung = KatalogDatei["exercises"][number];
export type Einstellung = Geraetetyp["settings"][number];

export type Pruefung<T> = { ok: true; wert: T } | { ok: false; fehler: string[] };

const TYPEN: Record<string, string> = {
  string: "Text",
  number: "Zahl",
  integer: "ganze Zahl",
  boolean: "Wahrheitswert",
  object: "Objekt",
  array: "Liste",
  null: "null",
};

function meldung(issue: z.ZodIssue): string {
  switch (issue.code) {
    case z.ZodIssueCode.invalid_type:
      // int() meldet eine Kommazahl als invalid_type mit expected "integer";
      // die eigene Meldung aus dem Schema sagt das verstaendlicher.
      if (issue.expected === "integer") return issue.message;
      return issue.received === "undefined"
        ? "fehlt"
        : `muss ${TYPEN[issue.expected] ?? issue.expected} sein, ist ${TYPEN[issue.received] ?? issue.received}`;
    case z.ZodIssueCode.invalid_literal:
      return `muss ${JSON.stringify(issue.expected)} sein`;
    case z.ZodIssueCode.invalid_enum_value:
      return `ist ${JSON.stringify(issue.received)}, erlaubt: ${issue.options.join(", ")}`;
    case z.ZodIssueCode.invalid_union_discriminator:
      return `muss ${issue.options.map(String).join(" oder ")} sein`;
    case z.ZodIssueCode.unrecognized_keys:
      return `unbekanntes Feld ${issue.keys.map((k) => `"${k}"`).join(", ")}`;
    default:
      return issue.message;
  }
}

function istObjekt(wert: unknown): wert is Record<string | number, unknown> {
  return typeof wert === "object" && wert !== null;
}

/** 'equipment[2] "laufband" secondary.max' -- Index und Schluessel, damit man den Eintrag findet. */
export function ort(roh: unknown, pfad: ReadonlyArray<string | number>): string {
  let text = "";
  let knoten: unknown = roh;
  for (const teil of pfad) {
    knoten = istObjekt(knoten) ? knoten[teil] : undefined;
    if (typeof teil === "number") {
      text += `[${teil}]`;
      if (istObjekt(knoten) && typeof knoten.key === "string") text += ` "${knoten.key}"`;
    } else {
      text += text === "" ? teil : text.endsWith('"') ? ` ${teil}` : `.${teil}`;
    }
  }
  return text === "" ? "Datei" : text;
}

function doppelte(werte: readonly string[]): string[] {
  const gesehen = new Set<string>();
  const doppelt = new Set<string>();
  for (const wert of werte) {
    if (gesehen.has(wert)) doppelt.add(wert);
    gesehen.add(wert);
  }
  return [...doppelt];
}

/** Was zod nicht sieht: Verweise zwischen Listen, Doppelte, Grenzen untereinander. */
function querPruefen(k: KatalogDatei): string[] {
  const fehler: string[] = [];
  const eindeutig = (wo: string, schluessel: string[]) => {
    for (const d of doppelte(schluessel)) fehler.push(`${wo}: Schluessel "${d}" kommt mehrfach vor`);
  };
  eindeutig("muscles", k.muscles.map((m) => m.key));
  eindeutig("sources", k.sources.map((q) => q.key));
  eindeutig("equipment", k.equipment.map((g) => g.key));
  eindeutig("exercises", k.exercises.map((u) => u.key));

  const uebungen = new Set(k.exercises.map((u) => u.key));
  const muskeln = new Set(k.muscles.map((m) => m.key));
  const quellen = new Set(k.sources.map((q) => q.key));
  const zugeordnet = new Set<string>();

  k.equipment.forEach((g, i) => {
    const wo = `equipment[${i}] "${g.key}"`;
    if (g.load_max !== null && g.load_max < g.load_min) fehler.push(`${wo}: load_max ist kleiner als load_min`);
    if (g.secondary !== null && g.secondary.max < g.secondary.min) {
      fehler.push(`${wo}: secondary.max ist kleiner als secondary.min`);
    }
    eindeutig(`${wo} settings`, g.settings.map((e) => e.key));
    g.settings.forEach((e, j) => {
      const woE = `${wo} settings[${j}] "${e.key}"`;
      if (e.kind === "number" && e.min !== null && e.max !== null && e.max < e.min) {
        fehler.push(`${woE}: max ist kleiner als min`);
      }
      if (e.kind === "enum") {
        for (const d of doppelte(e.allowed_values)) fehler.push(`${woE}: allowed_values enthaelt "${d}" mehrfach`);
      }
    });
    eindeutig(`${wo} exercises`, g.exercises);
    for (const u of g.exercises) {
      if (!uebungen.has(u)) fehler.push(`${wo} exercises: Uebung "${u}" gibt es in exercises nicht`);
      zugeordnet.add(u);
    }
  });

  k.exercises.forEach((u, i) => {
    const wo = `exercises[${i}] "${u.key}"`;
    if (u.target_max < u.target_min) fehler.push(`${wo}: target_max ist kleiner als target_min`);
    if (u.target_max > MAX_VOLUME[u.volume_kind]) {
      fehler.push(`${wo}: target_max ist groesser als ${MAX_VOLUME[u.volume_kind]} (Obergrenze fuer ${u.volume_kind})`);
    }
    // Eine Uebung ohne Geraetetyp waere in der App unerreichbar.
    if (!zugeordnet.has(u.key)) fehler.push(`${wo}: haengt an keinem Geraetetyp`);
    if (!u.muscles.some((m) => m.role === "primary")) {
      fehler.push(`${wo}: braucht mindestens einen Muskel mit role "primary"`);
    }
    for (const d of doppelte(u.muscles.map((m) => m.muscle))) fehler.push(`${wo} muscles: Muskel "${d}" kommt mehrfach vor`);
    for (const m of u.muscles) {
      if (!muskeln.has(m.muscle)) fehler.push(`${wo} muscles: Muskel "${m.muscle}" gibt es in muscles nicht`);
    }
    for (const q of u.sources) {
      if (!quellen.has(q)) fehler.push(`${wo} sources: Quelle "${q}" gibt es in sources nicht`);
    }
  });
  return fehler;
}

export function pruefeKatalog(roh: unknown): Pruefung<KatalogDatei> {
  const ergebnis = katalogSchema.safeParse(roh);
  if (!ergebnis.success) {
    return { ok: false, fehler: ergebnis.error.issues.map((issue) => `${ort(roh, issue.path)}: ${meldung(issue)}`) };
  }
  const fehler = querPruefen(ergebnis.data);
  return fehler.length > 0 ? { ok: false, fehler } : { ok: true, wert: ergebnis.data };
}
