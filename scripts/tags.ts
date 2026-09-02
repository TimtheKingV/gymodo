#!/usr/bin/env tsx
import { writeFileSync } from "node:fs";
import { parseArgs } from "node:util";
import { createClient } from "@supabase/supabase-js";
import "dotenv/config";
import { DomainError } from "@fitretro/domain";
import {
  bestand,
  chargeAnlegen,
  chargeVerschrotten,
  chargeZeilen,
  lieferungAnlegen,
  studioAufloesen,
  type TagSorte,
} from "@fitretro/domain/chargen";

/**
 * Das Betreiberwerkzeug. Es schreibt mit dem Service-Role-Schluessel und laeuft
 * irgendwann gegen das echte Projekt -- deshalb nennt es vor jeder schreibenden
 * Handlung sein Ziel und verlangt ausserhalb von 127.0.0.1 ein zusaetzliches
 * --ja.
 *
 * Tokens erscheinen nie auf stdout. Das einzige Erzeugnis, das sie im Klartext
 * zeigt, ist die CSV-Datei fuer den Lieferanten.
 */

const HILFE = `Aufruf: pnpm tags <befehl> [optionen]

  charge:anlegen      --code <text> --sorte machine|studio --menge <zahl>
                      [--lieferant <text>] [--bestellt <JJJJ-MM-TT>]
  charge:csv          --code <text> [--basis <url>] [--datei <pfad>]
  charge:verschrotten --code <text>
  lieferung           --charge <text> --studio <uuid|name>
                      (--menge <zahl> | --nummern 3-7,9)
  bestand             --studio <uuid|name>

  --ja                bestaetigt eine Schreibhandlung gegen ein nicht-lokales Ziel
`;

function pflicht(werte: Record<string, unknown>, name: string): string {
  const wert = werte[name];
  if (typeof wert !== "string" || wert === "") {
    throw new DomainError("validation_failed", `--${name} fehlt.`);
  }
  return wert;
}

function zahl(werte: Record<string, unknown>, name: string): number | undefined {
  const wert = werte[name];
  if (typeof wert !== "string") return undefined;
  const geparst = Number(wert);
  if (!Number.isInteger(geparst)) {
    throw new DomainError("validation_failed", `--${name} ist keine ganze Zahl.`);
  }
  return geparst;
}

/** "3-7,9" wird zu [3,4,5,6,7,9]. Bereiche und Aufzaehlungen gemischt. */
function nummern(werte: Record<string, unknown>): number[] | undefined {
  const wert = werte["nummern"];
  if (typeof wert !== "string") return undefined;

  const ergebnis = new Set<number>();
  for (const teil of wert.split(",")) {
    const bereich = teil.trim().match(/^(\d+)\s*-\s*(\d+)$/);
    if (bereich) {
      const von = Number(bereich[1]);
      const bis = Number(bereich[2]);
      if (bis < von) {
        throw new DomainError("validation_failed", `Der Bereich ${teil} laeuft rueckwaerts.`);
      }
      for (let n = von; n <= bis; n += 1) ergebnis.add(n);
      continue;
    }
    const einzeln = Number(teil.trim());
    if (!Number.isInteger(einzeln) || einzeln < 1) {
      throw new DomainError("validation_failed", `"${teil}" ist keine Nummer.`);
    }
    ergebnis.add(einzeln);
  }
  return [...ergebnis].sort((a, b) => a - b);
}

function sorte(werte: Record<string, unknown>): TagSorte {
  const wert = pflicht(werte, "sorte");
  if (wert !== "machine" && wert !== "studio") {
    throw new DomainError("validation_failed", "--sorte ist machine oder studio.");
  }
  return wert;
}

function umgebung(name: string): string {
  const wert = process.env[name];
  if (!wert) throw new DomainError("validation_failed", `Umgebungsvariable ${name} fehlt.`);
  return wert;
}

function zielPruefen(url: string, ja: boolean): void {
  console.log(`Ziel: ${url}`);
  const lokal = url.includes("127.0.0.1") || url.includes("localhost");
  if (!lokal && !ja) {
    throw new DomainError(
      "validation_failed",
      "Das ist kein lokales Ziel. Wiederhole den Aufruf mit --ja, wenn du das willst.",
    );
  }
}

async function main(): Promise<void> {
  const befehl = process.argv[2];
  if (!befehl || befehl === "--help" || befehl === "-h") {
    console.log(HILFE);
    return;
  }

  const { values } = parseArgs({
    args: process.argv.slice(3),
    options: {
      code: { type: "string" },
      sorte: { type: "string" },
      menge: { type: "string" },
      lieferant: { type: "string" },
      bestellt: { type: "string" },
      basis: { type: "string" },
      datei: { type: "string" },
      charge: { type: "string" },
      studio: { type: "string" },
      nummern: { type: "string" },
      ja: { type: "boolean", default: false },
    },
    strict: true,
  });

  const url = umgebung("SUPABASE_URL");
  const admin = createClient(url, umgebung("SUPABASE_SERVICE_ROLE_KEY"), {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  switch (befehl) {
    case "charge:anlegen": {
      zielPruefen(url, values.ja === true);
      const menge = zahl(values, "menge");
      if (menge === undefined) throw new DomainError("validation_failed", "--menge fehlt.");
      const charge = await chargeAnlegen(admin, {
        code: pflicht(values, "code"),
        kind: sorte(values),
        menge,
        lieferant: values.lieferant ?? null,
        bestelltAm: values.bestellt ?? null,
      });
      console.log(`Charge ${charge.code} angelegt: ${charge.quantity} Tags der Sorte ${charge.kind}.`);
      return;
    }

    case "charge:csv": {
      const code = pflicht(values, "code");
      const basis = values.basis ?? process.env["TAG_URL_BASE"];
      if (!basis) {
        throw new DomainError(
          "validation_failed",
          "--basis fehlt und TAG_URL_BASE ist nicht gesetzt. Eine CSV mit halben URLs ist beim Lieferanten nicht mehr zu reparieren.",
        );
      }
      const { charge, zeilen } = await chargeZeilen(admin, code);
      const ziel = values.datei ?? `charge-${charge.code}.csv`;
      const inhalt = [
        "nummer,charge,sorte,token,url",
        ...zeilen.map(
          (zeile) =>
            `${zeile.nummer},${charge.code},${charge.kind},${zeile.token},${basis.replace(/\/$/, "")}/t/${zeile.token}`,
        ),
      ].join("\n");
      writeFileSync(ziel, `${inhalt}\n`, "utf8");
      console.log(`${zeilen.length} Zeilen nach ${ziel} geschrieben.`);
      return;
    }

    case "charge:verschrotten": {
      zielPruefen(url, values.ja === true);
      const code = pflicht(values, "code");
      await chargeVerschrotten(admin, code);
      console.log(`Charge ${code} verschrottet. Sie liefert nichts mehr.`);
      return;
    }

    case "lieferung": {
      zielPruefen(url, values.ja === true);
      const studioId = await studioAufloesen(admin, pflicht(values, "studio"));
      const ergebnis = await lieferungAnlegen(admin, {
        chargeCode: pflicht(values, "charge"),
        studioId,
        menge: zahl(values, "menge"),
        nummern: nummern(values),
      });
      console.log(`Lieferung angelegt: ${ergebnis.menge} Tags an ${studioId}.`);
      return;
    }

    case "bestand": {
      const studioId = await studioAufloesen(admin, pflicht(values, "studio"));
      const zahlen = await bestand(admin, studioId);
      console.log(
        `geliefert ${zahlen.geliefert} - verbraucht ${zahlen.verbraucht} = vorraetig ${zahlen.vorraetig}`,
      );
      return;
    }

    default:
      throw new DomainError("validation_failed", `Unbekannter Befehl "${befehl}".\n\n${HILFE}`);
  }
}

main().catch((fehler: unknown) => {
  if (fehler instanceof DomainError) {
    console.error(`${fehler.code}: ${fehler.message}`);
    process.exit(1);
  }
  console.error(fehler);
  process.exit(1);
});
