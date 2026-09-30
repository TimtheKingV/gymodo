import { readdirSync, statSync } from "node:fs";
import path from "node:path";

/**
 * Der Verzeichnisbaum des App-Routers als serialisierbare Karte.
 *
 * Das ist der einzige Teil der Routenauflösung, der das Dateisystem
 * anfasst -- und er laeuft nur zur Bauzeit: `next.config.mjs` liest die
 * Karte einmal und legt sie per DefinePlugin ins Buendel. Zur Laufzeit
 * arbeitet `seitendatei.ts` nur noch auf dieser Karte, im Browser wie auf
 * dem Server.
 *
 * Deshalb .mjs und nicht .ts: `next.config.mjs` kann kein TypeScript laden.
 * Die Typen stehen in `seitendatei.ts` und werden hier per JSDoc geliehen.
 */

const ENDUNGEN = [".tsx", ".ts", ".jsx", ".js"];

/**
 * @param {string} wurzel Absoluter Pfad des `app`-Verzeichnisses.
 * @param {string} praefix Repo-relativer Praefix, z. B. `apps/web/app`.
 * @returns {import("./seitendatei").Routenknoten}
 */
export function karteLesen(wurzel, praefix) {
  return knotenLesen(wurzel, wurzel, praefix);
}

/**
 * @param {string} verzeichnis
 * @param {string} wurzel
 * @param {string} praefix
 * @returns {import("./seitendatei").Routenknoten}
 */
function knotenLesen(verzeichnis, wurzel, praefix) {
  /** @type {import("./seitendatei").Routenknoten} */
  const knoten = { kinder: {} };

  let eintraege = [];
  try {
    eintraege = readdirSync(verzeichnis);
  } catch {
    return knoten;
  }

  const seite = ENDUNGEN.map((endung) => `page${endung}`).find((name) => eintraege.includes(name));
  if (seite) knoten.seite = relativ(path.join(verzeichnis, seite), wurzel, praefix);

  const huelle = ENDUNGEN.map((endung) => `layout${endung}`).find((name) => eintraege.includes(name));
  if (huelle) knoten.huelle = relativ(path.join(verzeichnis, huelle), wurzel, praefix);

  for (const name of eintraege) {
    // Private Ordner (_bausteine) traegt der Router nicht als Route, und
    // was keine Route ist, gehoert nicht in die Karte.
    if (name.startsWith("_") || name.startsWith(".")) continue;
    const kind = path.join(verzeichnis, name);
    let istOrdner = false;
    try {
      istOrdner = statSync(kind).isDirectory();
    } catch {
      continue;
    }
    if (!istOrdner) continue;
    knoten.kinder[name] = knotenLesen(kind, wurzel, praefix);
  }

  return knoten;
}

/**
 * @param {string} absolut
 * @param {string} wurzel
 * @param {string} praefix
 * @returns {string}
 */
function relativ(absolut, wurzel, praefix) {
  const teil = path.relative(wurzel, absolut).split(path.sep).join("/");
  return teil ? `${praefix}/${teil}` : praefix;
}
