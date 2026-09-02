#!/usr/bin/env node
/**
 * Smoke-Test der ausgelieferten Anwendung.
 *
 * WARUM ES IHN GIBT: Am 1. September lieferte die Produktion auf `/`,
 * `/t/<token>` und jeder API-Route mit Bearer-Kopfzeile HTTP 500 --
 * `SUPABASE_URL` und `SUPABASE_ANON_KEY` fehlten in Vercel, und
 * `requiredEnv` warf bei jedem Client-Bau. `pnpm smoke:aasa` meldete
 * dabei gruen, weil die AASA-Route eine der wenigen ist, die *keinen*
 * Supabase-Client baut.
 *
 * Dieses Skript prueft deshalb bewusst BEIDE Klassen und benennt sie:
 * Routen ohne Client als Kontrollgruppe, Routen mit Client als
 * eigentliche Probe. Faellt nur die zweite Gruppe aus, ist es die
 * Umgebung; fallen beide aus, ist die Auslieferung selbst kaputt.
 *
 * Zweite Lehre desselben Tages: Vercel liefert Fehlerseiten aus dem
 * Edge-Cache. Nach dem Fix meldete curl weiter 500, obwohl die Seite
 * lief. Jede Anfrage hier traegt deshalb einen Cache-Buster.
 */

const domain = process.argv[2];
if (!domain) {
  console.error("Aufruf: node scripts/smoke-web.mjs <domain>");
  process.exit(2);
}

const basis = `https://${domain}`;

/** 22 Zeichen base64url -- formgueltig, aber mit Sicherheit unbekannt. */
const UNBEKANNTER_TOKEN = "smoketestsmoketesttoke";

async function hole(pfad, optionen = {}) {
  const trenner = pfad.includes("?") ? "&" : "?";
  const url = `${basis}${pfad}${trenner}cachebust=${Date.now()}-${Math.random()}`;
  const antwort = await fetch(url, { redirect: "manual", ...optionen });
  return { antwort, text: await antwort.text() };
}

/**
 * Jede Probe nennt, ob die Route einen Supabase-Client baut. Das ist die
 * Achse, an der sich der Ausfall vom 1. September ablesen liess.
 */
const proben = [
  {
    name: "/login",
    client: false,
    pfad: "/login",
    status: 200,
  },
  {
    name: "/api/aasa",
    client: false,
    pfad: "/api/aasa",
    status: 200,
  },
  {
    name: "/api/v1/me/bootstrap ohne Kopfzeile",
    client: false, // bearerClientFrom gibt vorher null zurueck
    pfad: "/api/v1/me/bootstrap",
    status: 401,
  },
  {
    name: "/",
    client: true,
    pfad: "/",
    status: 200,
    // 200 allein genuegt nicht: die Seite muss auch gerendert haben.
    enthaelt: "Nicht angemeldet",
  },
  {
    name: "/t/<unbekannter Token>",
    client: true,
    pfad: `/t/${UNBEKANNTER_TOKEN}`,
    status: 200,
  },
  {
    name: "/api/v1/me/bootstrap MIT Kopfzeile",
    client: true,
    pfad: "/api/v1/me/bootstrap",
    optionen: { headers: { authorization: "Bearer smoketest.ungueltig.abervorhanden" } },
    // Die schaerfste Probe: 401 heisst Client gebaut und JWT abgelehnt.
    // 500 heisst, requiredEnv hat geworfen -- die Umgebung fehlt.
    status: 401,
  },
];

const fehler = [];
const ergebnisse = [];

for (const probe of proben) {
  try {
    const { antwort, text } = await hole(probe.pfad, probe.optionen);
    const abweichungen = [];
    if (antwort.status !== probe.status) {
      abweichungen.push(`Status ${antwort.status}, erwartet ${probe.status}`);
    }
    if (probe.enthaelt && !text.includes(probe.enthaelt)) {
      abweichungen.push(`Rumpf enthaelt "${probe.enthaelt}" nicht`);
    }
    ergebnisse.push({ probe, status: antwort.status, abweichungen });
    if (abweichungen.length > 0) fehler.push({ probe, abweichungen });
  } catch (ursache) {
    const abweichungen = [`Anfrage fehlgeschlagen: ${ursache.message}`];
    ergebnisse.push({ probe, status: "—", abweichungen });
    fehler.push({ probe, abweichungen });
  }
}

for (const { probe, status, abweichungen } of ergebnisse) {
  const zeichen = abweichungen.length === 0 ? "OK  " : "FEHL";
  const klasse = probe.client ? "mit Client " : "ohne Client";
  console.log(`${zeichen} ${klasse}  ${String(status).padEnd(4)} ${probe.name}`);
}

if (fehler.length === 0) {
  console.log(`\nWeb-Smoke-Test bestanden fuer ${basis}`);
  process.exit(0);
}

console.error(`\nWeb-Smoke-Test fehlgeschlagen fuer ${basis}:`);
for (const { probe, abweichungen } of fehler) {
  for (const abweichung of abweichungen) {
    console.error(`  - ${probe.name}: ${abweichung}`);
  }
}

// Die Diagnose, die heute eine Stunde gekostet hat -- einmal ausgeschrieben.
const mitClient = fehler.filter(({ probe }) => probe.client).length;
const ohneClient = fehler.filter(({ probe }) => !probe.client).length;
if (mitClient > 0 && ohneClient === 0) {
  console.error(
    "\nNur Routen MIT Supabase-Client fallen aus. Das ist das Muster einer" +
      "\nfehlenden Umgebungsvariable: pruefe SUPABASE_URL und SUPABASE_ANON_KEY" +
      "\nin Vercel (die NEXT_PUBLIC_-Varianten genuegen nicht -- der Server" +
      "\nliest die Namen ohne Praefix) und deploye danach neu.",
  );
}
process.exit(1);
