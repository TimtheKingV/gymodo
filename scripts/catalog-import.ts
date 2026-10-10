#!/usr/bin/env tsx
import { parseArgs } from "node:util";
import { createClient } from "@supabase/supabase-js";
import "dotenv/config";
import { DomainError } from "@fitretro/domain";
import { berichtText, importiereKatalog, ladeKatalog } from "@fitretro/domain/katalog-import";

/**
 * Gleicht den Gymtavo-Katalog mit catalog/gymtavo.json ab (Spec 9.1). Schreibt
 * mit dem Service-Role-Schluessel und laeuft irgendwann gegen Produktion --
 * deshalb nennt es sein Ziel und verlangt ausserhalb von 127.0.0.1 ein --ja,
 * wie pnpm tags. Der Trockenlauf schreibt nichts und braucht es nicht.
 */

const HILFE = `Aufruf: pnpm catalog:import [datei] [--dry-run] [--ja]

  datei      Katalogdatei, Vorgabe catalog/gymtavo.json
  --dry-run  zeigt den Plan; laedt nichts hoch und schreibt nichts
  --ja       bestaetigt das Schreiben gegen ein nicht-lokales Ziel
`;

function umgebung(name: string): string {
  const wert = process.env[name];
  if (!wert) throw new DomainError("validation_failed", `Umgebungsvariable ${name} fehlt.`);
  return wert;
}

async function main(): Promise<void> {
  const { values, positionals } = parseArgs({
    allowPositionals: true,
    options: {
      "dry-run": { type: "boolean", default: false },
      ja: { type: "boolean", default: false },
      hilfe: { type: "boolean", short: "h", default: false },
    },
  });
  if (values.hilfe === true || positionals.length > 1) {
    console.log(HILFE);
    return;
  }

  const datei = positionals[0] ?? "catalog/gymtavo.json";
  const geladen = ladeKatalog(datei);
  if (!geladen.ok) {
    console.error(`${geladen.fehler.length} Fehler in ${datei}, nichts geschrieben:`);
    for (const fehler of geladen.fehler) console.error(`  ${fehler}`);
    process.exit(1);
  }

  const url = umgebung("SUPABASE_URL");
  const trocken = values["dry-run"] === true;
  console.log(`Ziel: ${url}${trocken ? " (Trockenlauf)" : ""}`);
  const lokal = url.includes("127.0.0.1") || url.includes("localhost");
  if (!lokal && !trocken && values.ja !== true) {
    throw new DomainError(
      "validation_failed",
      "Das ist kein lokales Ziel. Wiederhole den Aufruf mit --ja, wenn du das willst.",
    );
  }

  const admin = createClient(url, umgebung("SUPABASE_SERVICE_ROLE_KEY"), {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { plan, geschrieben } = await importiereKatalog(admin, geladen.wert.katalog, geladen.wert.medien, { trocken });
  console.log(berichtText(plan));
  console.log(
    geschrieben === null
      ? "Trockenlauf: nichts hochgeladen, nichts geschrieben."
      : `Geschrieben: ${geschrieben.uploads} Uploads, ${geschrieben.geraetetypen} Geraetetypen, ${geschrieben.einstellungen} Einstellungen, ${geschrieben.uebungen} Uebungen, ${geschrieben.verknuepfungen} Verknuepfungen, ${geschrieben.videos} Videos.`,
  );
}

main().catch((fehler: unknown) => {
  if (fehler instanceof DomainError) {
    console.error(`${fehler.code}: ${fehler.message}`);
    process.exit(1);
  }
  console.error(fehler);
  process.exit(1);
});
