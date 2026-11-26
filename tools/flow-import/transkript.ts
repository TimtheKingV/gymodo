#!/usr/bin/env tsx
import { spawnSync } from "node:child_process";
import { mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

/**
 * Holt die deutschen Untertitel eines YouTube-Videos und schreibt sie als
 * bereinigtes transkript.txt ("m:ss Text"). Das ist der erste Schritt, um aus
 * einem Kurs einen Flow-Entwurf zu bauen. Ein Versuch, kein Wiederholen:
 * bei HTTP 429 lieber abbrechen und spaeter erneut starten.
 */

const ZEIT = /^(\d+):(\d{2}):(\d{2})\.\d{3}\s+-->/;

/** Bereinigt den Text einer YouTube-Auto-Untertitel-Datei (.vtt) zu "m:ss Text"-Zeilen. */
export function bereinigeVtt(vtt: string): string[] {
  const zeilen: string[] = [];
  let sekunden = 0;
  let zuletzt = "";
  for (const roh of vtt.split(/\r?\n/)) {
    const zeit = ZEIT.exec(roh.trim());
    if (zeit) {
      sekunden = Number(zeit[1]) * 3600 + Number(zeit[2]) * 60 + Number(zeit[3]);
      continue;
    }
    const text = roh.replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim();
    if (!text) continue;
    if (/^(WEBVTT|Kind:|Language:|NOTE)/.test(text)) continue;
    if (text === zuletzt) continue;
    zuletzt = text;
    const min = Math.floor(sekunden / 60);
    zeilen.push(`${min}:${String(sekunden % 60).padStart(2, "0")} ${text}`);
  }
  return zeilen;
}

function fehler(meldung: string): never {
  console.error(meldung);
  process.exit(1);
}

function main(): void {
  const [url, ausgabe] = process.argv.slice(2);
  if (!url || !ausgabe) fehler("Aufruf: pnpm flow:transkript <youtube-url> <ausgabeordner>");
  mkdirSync(ausgabe, { recursive: true });

  const lauf = spawnSync(
    "yt-dlp",
    [
      "--skip-download",
      "--write-auto-subs",
      "--write-subs",
      "--sub-langs",
      "de.*",
      "--no-playlist",
      "-o",
      join(ausgabe, "%(id)s"),
      url,
    ],
    { encoding: "utf8" },
  );
  if (lauf.error) fehler(`yt-dlp konnte nicht gestartet werden: ${lauf.error.message}`);
  const ausgabeText = `${lauf.stdout}\n${lauf.stderr}`;
  if (/HTTP Error 429|Too Many Requests/i.test(ausgabeText)) {
    fehler("YouTube antwortet mit 429 (zu viele Anfragen). Bitte spaeter erneut versuchen.");
  }
  if (lauf.status !== 0) fehler(`yt-dlp ist fehlgeschlagen (Code ${lauf.status}):\n${lauf.stderr}`);

  const datei = readdirSync(ausgabe).find((f) => f.endsWith(".vtt"));
  if (!datei) fehler("Keine deutschen Untertitel fuer dieses Video gefunden.");
  const zeilen = bereinigeVtt(readFileSync(join(ausgabe, datei), "utf8"));
  writeFileSync(join(ausgabe, "transkript.txt"), `${zeilen.join("\n")}\n`);
  console.log(`transkript.txt mit ${zeilen.length} Zeilen in ${ausgabe} geschrieben.`);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main();
