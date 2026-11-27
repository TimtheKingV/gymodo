#!/usr/bin/env tsx
import { readFileSync, realpathSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { pruefeFlowEntwurf, type FlowEntwurf } from "./entwurf";

/**
 * Erzeugt aus einem geprueften Flow-Entwurf idempotentes Seed-SQL (eine
 * Transaktion). Das Werkzeug verbindet sich nie mit einer Datenbank: das SQL
 * wird auf stdout geschrieben und von Hand eingespielt.
 */

const KATALOG_DATEI = fileURLToPath(new URL("../../catalog/gymtavo.json", import.meta.url));

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Studio, dem der Gymtavo-Katalog gehoert (Migration 0047); Uebungen dort tragen catalog_key (0048). */
const GYMTAVO_KATALOG_STUDIO = "00000000-0000-4000-8000-000000000001";

function lit(v: string | null): string {
  return v === null ? "null" : `'${v.replace(/'/g, "''")}'`;
}

export function flowZuSql(e: FlowEntwurf, studioId: string, katalogKeys?: ReadonlySet<string>): string {
  if (!UUID.test(studioId)) throw new Error("Die Studio-ID ist keine gueltige UUID.");
  const entwurf = pruefeFlowEntwurf(e);
  const unsicher = entwurf.schritte.flatMap((s, i) => (s.unsicher ? [`${i + 1} (${s.name})`] : []));
  if (unsicher.length > 0) {
    throw new Error(`Der Entwurf hat unsichere Schritte, die erst geklaert werden muessen: ${unsicher.join(", ")}.`);
  }

  if (katalogKeys) {
    const unbekannt = entwurf.schritte.flatMap((s, i) =>
      s.uebung !== undefined && !katalogKeys.has(s.uebung) ? [`${i + 1} (${s.uebung})`] : [],
    );
    if (unbekannt.length > 0) throw new Error(`Unbekannte Katalogschluessel: ${unbekannt.join(", ")}.`);
  }

  const studio = lit(studioId);
  const flowId = `(select id from public.flows where studio_id = ${studio} and key = ${lit(entwurf.key)})`;
  const zeilen = [
    "begin;",
    "",
    "insert into public.flows (studio_id, key, titel, beschreibung, level, source_url, source_channel)",
    `values (${studio}, ${lit(entwurf.key)}, ${lit(entwurf.titel)}, ${lit(entwurf.beschreibung)}, ${lit(entwurf.level)}, ${lit(entwurf.quelle.url)}, ${lit(entwurf.quelle.kanal)})`,
    "on conflict (studio_id, key) do update set",
    "  titel = excluded.titel,",
    "  beschreibung = excluded.beschreibung,",
    "  level = excluded.level,",
    "  source_url = excluded.source_url,",
    "  source_channel = excluded.source_channel;",
    "",
    `delete from public.flow_steps where flow_id = ${flowId};`,
    "",
  ];
  entwurf.schritte.forEach((s, i) => {
    const uebung =
      s.uebung === undefined
        ? null
        : `(select id from public.exercises where studio_id = ${lit(GYMTAVO_KATALOG_STUDIO)} and catalog_key = ${lit(s.uebung)})`;
    zeilen.push(
      `insert into public.flow_steps (flow_id, position, name, beschreibung, work_s, rest_s, is_warmup${uebung ? ", exercise_id" : ""})`,
      `values (${flowId}, ${i + 1}, ${lit(s.name)}, ${lit(s.beschreibung)}, ${s.workS}, ${s.restS}, ${s.istWarmup ? "true" : "false"}${uebung ? `, ${uebung}` : ""});`,
    );
  });
  const mitUebung = entwurf.schritte.filter((s) => s.uebung !== undefined).length;
  if (mitUebung > 0) {
    // Sicherung: loest ein Schluessel zu keiner Katalogzeile auf, bleibt exercise_id null.
    zeilen.push(
      "",
      "do $$",
      "begin",
      `  if (select count(*) from public.flow_steps where flow_id = ${flowId} and exercise_id is not null) <> ${mitUebung} then`,
      `    raise exception 'Flow ${entwurf.key}: mindestens ein Katalogschluessel wurde in public.exercises nicht gefunden';`,
      "  end if;",
      "end $$;",
    );
  }
  zeilen.push("", "commit;", "");
  return zeilen.join("\n");
}

function fehler(meldung: string): never {
  console.error(meldung);
  process.exit(1);
}

function main(): void {
  const args = process.argv.slice(2);
  const i = args.indexOf("--studio");
  const studio = i >= 0 ? args[i + 1] : undefined;
  const datei = args.find((a, j) => !a.startsWith("--") && j !== i + 1);
  if (!datei || !studio) fehler("Aufruf: pnpm flow:sql <flow.json> --studio <uuid>");
  try {
    const entwurf = pruefeFlowEntwurf(JSON.parse(readFileSync(datei, "utf8")));
    const katalog = JSON.parse(readFileSync(KATALOG_DATEI, "utf8")) as { exercises: Array<{ key: string }> };
    const katalogKeys = new Set(katalog.exercises.map((x) => x.key));
    process.stdout.write(flowZuSql(entwurf, studio, katalogKeys));
  } catch (err) {
    fehler(err instanceof Error ? err.message : String(err));
  }
}

function alsSkript(): boolean {
  try {
    return realpathSync(process.argv[1] ?? "") === realpathSync(fileURLToPath(import.meta.url));
  } catch {
    return false;
  }
}

if (alsSkript()) main();
