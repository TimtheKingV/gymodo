/**
 * `sitzung.md` -- die Datei, die Claude Code liest. Eine reine Funktion
 * ueber die Werte: kein `new Date()`, kein Dateisystem. Aufbau und Regeln
 * wie in `TestnotizMarkdown.swift`, damit ein Leser beide Plattformen
 * gleich liest.
 */

import type { ElementAngabe, Eintrag, Sitzung } from "./format";
import { datumUhrzeit, uhrzeit } from "./zeit";

export function rendern(sitzung: Sitzung): string {
  const teile = [kopf(sitzung), ...sitzung.entries.map(abschnitt)];
  return teile.join("\n\n") + "\n";
}

export function kopf(sitzung: Sitzung): string {
  const s = sitzung.session;
  return `# Testsitzung ${datumUhrzeit(s.startedAt)} — gymodo Portal ${s.app.version} (${s.app.build}), ${s.device.model}, ${s.device.os}`;
}

export function artName(art: Eintrag["kind"]): string {
  switch (art) {
    case "crop":
      return "Ausschnitt";
    case "element":
      return "Element";
    case "note":
      return "Notiz";
  }
}

export function abschnitt(e: Eintrag): string {
  const zeilen: string[] = [];
  const screenName = e.screen?.name ?? "unbekannter Screen";
  zeilen.push(`## ${e.index} · ${uhrzeit(e.createdAt)} · ${artName(e.kind)} · ${screenName}`);

  if (e.screen) {
    const kontext = Object.keys(e.screen.context)
      .sort()
      .map((schluessel) => `${schluessel} ${e.screen!.context[schluessel]}`)
      .join(", ");
    zeilen.push(`**Screen:** \`${e.screen.file}\`` + (kontext ? ` (${kontext})` : ""));
    if (e.screen.stack.length > 1) {
      zeilen.push("**Ebenen:** " + e.screen.stack.map(ebenenname).join(" → "));
    }
  } else {
    zeilen.push("**Screen:** unbekannt — kein Screen hat sich gemeldet");
  }

  if (e.element) {
    zeilen.push("**Element:** " + elementZeile(e.element));
  }

  if (e.note) {
    zeilen.push(`**Notiz:** ${e.note}`);
  }
  if (e.audio) {
    if (e.transcript) {
      zeilen.push(`**Gesprochen:** ${e.transcript} ([Audio](${e.audio}))`);
    } else {
      zeilen.push(`**Gesprochen:** Transkript fehlt, Audio liegt bei: [${e.audio}](${e.audio})`);
    }
  }

  const bilder: string[] = [];
  if (e.crop) bilder.push(`![Ausschnitt](${e.crop})`);
  bilder.push(`![Vollbild](${e.screenshot})`);
  zeilen.push(bilder.join("\n"));

  if (e.log.length > 0) {
    const anzahl = e.log.length === 1 ? "1 Zeile" : `${e.log.length} Zeilen`;
    const protokoll = e.log
      .map((zeile) => `${uhrzeit(zeile.at, true)} ${zeile.level} ${zeile.category} — ${zeile.message}`)
      .join("\n");
    zeilen.push(
      `<details><summary>Protokoll (letzte 5 min, ${anzahl})</summary>\n\n${protokoll}\n\n</details>`,
    );
  }

  return zeilen.join("\n\n");
}

export function elementZeile(e: ElementAngabe): string {
  const teile: string[] = [];
  if (e.identifier) teile.push(`\`${e.identifier}\``);
  const beschreibung: string[] = [];
  if (e.label) beschreibung.push(`„${e.label}“`);
  beschreibung.push(e.type);
  if (e.file && e.line !== null) beschreibung.push(`\`${e.file}:${e.line}\``);
  teile.push(beschreibung.join(", "));
  return teile.join(" — ");
}

/**
 * Der Ebenenname einer Web-Ebene ist der Ordner, nicht der Dateiname: jede
 * Seite im App-Router heisst `page.tsx`, jede Huelle `layout.tsx`. Die
 * Klammergruppen (`(schreibtisch)`) fallen weg, sie sind keine Ebene im
 * Sinn des Formats.
 */
function ebenenname(datei: string): string {
  const teile = datei.split("/");
  const dateiname = teile.pop() ?? datei;
  const art = dateiname.replace(/\.[jt]sx?$/, "");
  const ordner = [...teile].reverse().find((teil) => !teil.startsWith("(")) ?? "app";
  return art === "page" ? ordner : `${ordner}/${art}`;
}
