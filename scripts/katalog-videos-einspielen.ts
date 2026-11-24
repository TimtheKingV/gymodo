#!/usr/bin/env tsx
import { spawnSync } from "node:child_process";
import { copyFileSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { parseArgs } from "node:util";
import { plane, setzeVideos } from "@fitretro/domain/katalog-videos-tausch";

const HILFE = `Aufruf: pnpm catalog:videos <ordner> [--ja]

Spielt die abgenommenen Loops (<schluessel>.mp4) in den Katalog ein:
kopiert sie nach catalog/media/videos/ und setzt video.file und
video.duration_s in catalog/gymtavo.json. Sonst bleibt die Datei
zeichengleich. Ohne --ja nur Bericht, es wird nichts geschrieben.`;

const KATALOG = "catalog/gymtavo.json";
const ZIEL = "catalog/media/videos";

const { values, positionals } = parseArgs({ allowPositionals: true, options: { ja: { type: "boolean", default: false }, help: { type: "boolean", default: false } } });
if (values.help || positionals.length !== 1) {
  console.log(HILFE);
  process.exit(values.help ? 0 : 1);
}
const ordner = resolve(positionals[0]!);

/** 640x640 und keine Tonspur, sonst Fehlertext. */
function formatFehler(pfad: string): string | null {
  const r = spawnSync("ffprobe", ["-v", "error", "-show_entries", "stream=codec_type,width,height", "-of", "csv=p=0", pfad], { encoding: "utf8" });
  if (r.status !== 0) return "ffprobe konnte die Datei nicht lesen";
  const zeilen = r.stdout.trim().split("\n");
  if (zeilen.some((z) => z.startsWith("audio"))) return "hat eine Tonspur";
  const v = zeilen.find((z) => z.startsWith("video"));
  return v === "video,640,640" ? null : `Format ${v ?? "?"} statt 640x640`;
}

const text = readFileSync(KATALOG, "utf8");
const katalog = JSON.parse(text) as { exercises: { key: string; volume_kind: "reps" | "seconds"; video: { file: string; duration_s: number } | null }[] };
const namen = readdirSync(ordner).filter((n) => n.endsWith(".mp4")).sort();
const dateien = namen.map((n) => ({ key: n.slice(0, -4), bytes: new Uint8Array(readFileSync(join(ordner, n))) }));

const formatFehlerListe = namen.flatMap((n) => {
  const f = formatFehler(join(ordner, n));
  return f ? [`${n}: ${f}`] : [];
});
const plan = plane(katalog.exercises, dateien);
if (!plan.ok || formatFehlerListe.length > 0) {
  console.error(["Abbruch, nichts geschrieben:", ...(plan.ok ? [] : plan.fehler), ...formatFehlerListe].join("\n  "));
  process.exit(1);
}

const verteilung = new Map<number, number>();
for (const e of plan.eintraege.values()) verteilung.set(e.duration_s, (verteilung.get(e.duration_s) ?? 0) + 1);
console.log(`${dateien.length} Dateien: ${plan.neu.length} neu, ${plan.ersetzt.length} ersetzt.`);
console.log(`Laengen (duration_s): ${[...verteilung].sort((a, b) => a[0] - b[0]).map(([s, n]) => `${s} s x ${n}`).join(", ")}`);
if (!values.ja) {
  console.log("Nur Bericht. Mit --ja schreiben.");
  process.exit(0);
}

mkdirSync(ZIEL, { recursive: true });
for (const n of namen) copyFileSync(join(ordner, n), join(ZIEL, n));
writeFileSync(KATALOG, setzeVideos(text, plan.eintraege));
console.log("Geschrieben.");
