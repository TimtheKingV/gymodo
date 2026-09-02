#!/usr/bin/env node
/**
 * Vergleicht die Migrationen auf Platte mit denen des verknuepften
 * Supabase-Projekts.
 *
 * WARUM ES IHN GIBT: Am 1. September stand die Produktionsdatenbank auf
 * `0011`, waehrend das Repo bei `0021` war -- zehn Migrationen waren nach
 * dem Zuruecksetzen vom 30. August nie gepusht worden. Nichts hat das
 * gemeldet, und nichts haette es gemeldet: `/t/<token>` antwortete
 * weiterhin mit 200, weil ein unbekannter Token die leere Menge liefert
 * und die Seite korrekt "unbekannt" zeigt, ohne je eine Spalte zu lesen.
 * Erst der erste echte Tag haette den Signaturbruch von
 * `resolve_tag_fallback` zum Vorschein gebracht -- vor einem Betreiber.
 *
 * Ein Rueckstand dieser Art meldet sich nicht von selbst. Er wartet auf
 * den ersten echten Datensatz. Deshalb wird er hier abgefragt.
 */

import { exec } from "node:child_process";
import { readdir } from "node:fs/promises";
import { promisify } from "node:util";

const execAsync = promisify(exec);

/** `supabase migration list` schreibt Fortschritt und am Ende eine JSON-Zeile. */
function letzteJsonZeile(ausgabe) {
  const zeilen = ausgabe.split(/\r?\n/).filter((z) => z.trim().startsWith("{"));
  for (const zeile of zeilen.reverse()) {
    try {
      return JSON.parse(zeile);
    } catch {
      // naechste versuchen
    }
  }
  return null;
}

const aufPlatte = (await readdir("supabase/migrations"))
  .filter((name) => name.endsWith(".sql"))
  .map((name) => name.slice(0, name.indexOf("_")))
  .sort();

let ausgabe;
try {
  // exec mit einer festen Zeichenkette statt execFile mit Args-Array:
  // Unter Windows verweigert Node seit dem Fix fuer CVE-2024-27980 das
  // Starten einer .cmd ohne Shell (EINVAL), und ein Args-Array *mit*
  // shell:true ist seit DEP0190 abgekuendigt, weil Argumente dabei
  // unmaskiert zusammengehaengt werden. Hier kommt nichts von aussen in
  // die Kommandozeile -- das Kommando ist ein Literal.
  const { stdout, stderr } = await execAsync(
    "pnpm exec supabase migration list",
    { maxBuffer: 10 * 1024 * 1024 },
  );
  ausgabe = `${stdout}\n${stderr}`;
} catch (ursache) {
  console.error("Migrationsabgleich fehlgeschlagen: `supabase migration list` lief nicht.");
  console.error(`  ${ursache.message.split("\n")[0]}`);
  console.error("  Ist ein Projekt verknuepft (`supabase link`) und die Anmeldung gueltig?");
  process.exit(2);
}

const bericht = letzteJsonZeile(ausgabe);
if (!bericht?.migrations) {
  console.error("Migrationsabgleich fehlgeschlagen: keine auswertbare Antwort der CLI.");
  process.exit(2);
}

const nurLokal = bericht.migrations.filter((m) => m.local && !m.remote).map((m) => m.local);
const nurEntfernt = bericht.migrations.filter((m) => m.remote && !m.local).map((m) => m.remote);

console.log(`Auf Platte: ${aufPlatte.length} Migrationen (bis ${aufPlatte.at(-1) ?? "—"})`);
console.log(`Im Projekt: ${bericht.migrations.filter((m) => m.remote).length} angewendet`);

if (nurLokal.length === 0 && nurEntfernt.length === 0) {
  console.log("\nMigrationsabgleich bestanden: Platte und Projekt stehen gleich.");
  process.exit(0);
}

console.error("\nMigrationsabgleich fehlgeschlagen:");
if (nurLokal.length > 0) {
  console.error(`  - nur auf Platte, im Projekt NICHT angewendet: ${nurLokal.join(", ")}`);
  console.error("    Behebung: `pnpm exec supabase db push`");
}
if (nurEntfernt.length > 0) {
  console.error(`  - nur im Projekt, nicht auf Platte: ${nurEntfernt.join(", ")}`);
  console.error("    Das Projekt kennt Migrationen, die dieses Arbeitsverzeichnis nicht hat.");
  console.error("    Vermutlich ein anderer Branch oder ein Griff ins Dashboard.");
}
process.exit(1);
