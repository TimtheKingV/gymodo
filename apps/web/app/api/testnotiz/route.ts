import path from "node:path";
import { z } from "zod";
import { eintragSchreiben, sitzungAnlegen, sitzungLesen } from "@/lib/testnotiz/ablage";
import type { Screen, Sitzungskopf } from "@/lib/testnotiz/format";
import { seiteFinden } from "@/lib/testnotiz/seitendatei";

/**
 * Der Eingang des Testnotiz-Moduls: der Browser schickt Bild und Notiz, der
 * Dev-Server legt den Ordner an, den Claude Code liest.
 *
 * **Nur im Dev-Server.** In einem Produktionsbau antwortet jede Methode mit
 * 404 -- das Modul selbst wird dort schon gar nicht geladen (TestnotizMontage),
 * aber eine Route, die Dateien schreibt, darf sich nicht auf den Aufrufer
 * verlassen.
 */

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const PRAEFIX = "apps/web/app";

function nurDev(): Response | null {
  if (process.env.NODE_ENV === "production") {
    return new Response(null, { status: 404 });
  }
  return null;
}

/** `next dev` laeuft in `apps/web`; der Eingang liegt daneben. */
function ablagewurzel(): string {
  return path.join(process.cwd(), "testnotizen");
}

const rechteck = z.object({
  x: z.number(),
  y: z.number(),
  width: z.number(),
  height: z.number(),
});

const entwurfSchema = z.object({
  id: z.string().min(1),
  createdAt: z.string().min(1),
  kind: z.enum(["crop", "element", "note"]),
  cropRect: z.object({ points: rechteck, pixels: rechteck }).nullable(),
  element: z
    .object({
      source: z.literal("dom"),
      identifier: z.string().nullable(),
      label: z.string().nullable(),
      type: z.string(),
      frame: rechteck,
      file: z.string().nullable(),
      line: z.number().int().nullable(),
    })
    .nullable(),
  note: z.string().nullable(),
  runtime: z.object({
    online: z.boolean(),
    pendingWrites: z.number().int(),
    signedIn: z.boolean(),
    studioId: z.string().nullable(),
  }),
  log: z.array(
    z.object({
      at: z.string(),
      level: z.enum(["debug", "info", "notice", "error", "fault", "undefined"]),
      category: z.string(),
      message: z.string(),
    }),
  ),
});

const kopfSchema = z.object({
  startedAt: z.string().min(1),
  device: z.object({
    model: z.string(),
    os: z.string(),
    screen: z.object({ width: z.number(), height: z.number(), scale: z.number() }),
  }),
});

const ortSchema = z.object({
  pfad: z.string().default("/"),
  suche: z.string().default(""),
  kontext: z.record(z.string()).default({}),
});

export async function GET(request: Request): Promise<Response> {
  const aus = nurDev();
  if (aus) return aus;

  const id = new URL(request.url).searchParams.get("sitzung");
  if (!id) return Response.json({ error: "sitzung fehlt" }, { status: 400 });

  const sitzung = await sitzungLesen(ablagewurzel(), id);
  if (!sitzung) return Response.json({ error: "unbekannte Sitzung" }, { status: 404 });

  return Response.json({
    sitzung: sitzung.session.id,
    ordner: `apps/web/testnotizen/${sitzung.session.id}`,
    anzahl: sitzung.entries.length,
  });
}

export async function POST(request: Request): Promise<Response> {
  const aus = nurDev();
  if (aus) return aus;

  let formular: FormData;
  try {
    formular = await request.formData();
  } catch {
    return Response.json({ error: "kein Formular" }, { status: 400 });
  }

  const entwurf = entwurfSchema.safeParse(json(formular.get("eintrag")));
  if (!entwurf.success) {
    return Response.json({ error: "Eintrag unvollstaendig", details: entwurf.error.format() }, { status: 400 });
  }

  const ort = ortSchema.safeParse(json(formular.get("ort")));
  if (!ort.success) {
    return Response.json({ error: "Ort unvollstaendig" }, { status: 400 });
  }

  const voll = formular.get("voll");
  if (!(voll instanceof Blob)) {
    return Response.json({ error: "Vollbild fehlt" }, { status: 400 });
  }
  const ausschnitt = formular.get("ausschnitt");

  const wurzel = ablagewurzel();

  let id = typeof formular.get("sitzung") === "string" ? String(formular.get("sitzung")) : "";
  if (id && !(await sitzungLesen(wurzel, id))) {
    // Der Browser merkt sich die Sitzung ueber Neuladen hinweg; der Ordner
    // kann in der Zwischenzeit umgezogen oder geloescht worden sein.
    id = "";
  }
  if (!id) {
    const kopf = kopfSchema.safeParse(json(formular.get("kopf")));
    if (!kopf.success) {
      return Response.json({ error: "Sitzungskopf unvollstaendig" }, { status: 400 });
    }
    const sitzung = await sitzungAnlegen(wurzel, vollstaendigerKopf(kopf.data));
    id = sitzung.session.id;
  }

  try {
    const { eintrag, anzahl } = await eintragSchreiben(
      wurzel,
      id,
      entwurf.data,
      screenBestimmen(ort.data),
      new Uint8Array(await voll.arrayBuffer()),
      ausschnitt instanceof Blob ? new Uint8Array(await ausschnitt.arrayBuffer()) : null,
    );
    return Response.json({
      sitzung: id,
      ordner: `apps/web/testnotizen/${id}`,
      index: eintrag.index,
      anzahl,
    });
  } catch (fehler) {
    const text = fehler instanceof Error ? fehler.message : "unbekannter Fehler";
    return Response.json({ error: text }, { status: 500 });
  }
}

function json(wert: FormDataEntryValue | null): unknown {
  if (typeof wert !== "string") return undefined;
  try {
    return JSON.parse(wert);
  } catch {
    return undefined;
  }
}

function vollstaendigerKopf(teil: z.infer<typeof kopfSchema>): Sitzungskopf {
  return {
    id: "",
    startedAt: teil.startedAt,
    app: {
      bundleId: "gymodo.web.portal",
      version: process.env.npm_package_version ?? "0.0.0",
      build: "dev",
      // Wie auf iOS: das Modul laeuft nur im Entwicklungsbau.
      configuration: "Debug",
    },
    device: teil.device,
  };
}

function screenBestimmen(ort: z.infer<typeof ortSchema>): Screen | null {
  const treffer = seiteFinden(ort.pfad, {
    wurzel: path.join(process.cwd(), "app"),
    praefix: PRAEFIX,
  });
  if (!treffer) return null;

  const context: Record<string, string> = { ...treffer.parameter };
  for (const [schluessel, wert] of new URLSearchParams(ort.suche)) {
    context[schluessel] = wert;
  }
  for (const [schluessel, wert] of Object.entries(ort.kontext)) {
    context[schluessel] = wert;
  }

  return { name: treffer.name, file: treffer.datei, stack: treffer.stapel, context };
}
