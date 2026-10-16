#!/usr/bin/env node
// Erzeugt die Pfaddaten des Muskelmodells fuer die App aus den vier SVGs in
// assets/muskelmodell/ (Revision 4). Die App zeichnet die Pfade nativ; sie
// bekommt nur, was sie zum Zeichnen braucht: viewBox, Koerper- und
// Detailpfade, Muskelpfade mit Schluessel und ihre Ausschnitte.
//
// Aufruf: node scripts/muskelmodell-json.mjs
// Die Ausgabe ist deterministisch: Reihenfolge wie in den SVGs, Koordinaten
// unveraendert als Text uebernommen.
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const wurzel = join(dirname(fileURLToPath(import.meta.url)), "..");
const quelle = join(wurzel, "assets/muskelmodell");
const ziel = join(wurzel, "apps/ios-member/FitnessMember/Resources/muskelmodell.json");

const dateien = {
  maennlich: { vorne: "muscles-front.svg", hinten: "muscles-back.svg" },
  weiblich: { vorne: "muscles-female-front.svg", hinten: "muscles-female-back.svg" },
};

function attribut(tag, name) {
  const treffer = tag.match(new RegExp(`\\s${name}="([^"]*)"`));
  return treffer ? treffer[1] : undefined;
}

function zahlen(text) {
  return text.trim().split(/[\s,]+/).map(Number);
}

function ansicht(datei) {
  const svg = readFileSync(join(quelle, datei), "utf8");
  const wurzelTag = svg.match(/<svg\b[^>]*>/)[0];
  const viewBox = zahlen(attribut(wurzelTag, "viewBox"));

  // Ausschnitte: Schulter als Rechteck, Wade (nur hinten) als Pfad.
  const rechtecke = {};
  const clipPfade = {};
  for (const [, id, inhalt] of svg.matchAll(/<clipPath id="([^"]+)">(.*?)<\/clipPath>/gs)) {
    const rect = inhalt.match(/^<rect\b[^>]*\/>$/);
    const pfad = inhalt.match(/^<path\b[^>]*\/>$/);
    if (rect) {
      rechtecke[id] = ["x", "y", "width", "height"].map((n) => Number(attribut(rect[0], n)));
    } else if (pfad) {
      clipPfade[id] = attribut(pfad[0], "d");
    } else {
      throw new Error(`${datei}: clipPath ${id} ist weder ein einzelnes rect noch ein einzelner path`);
    }
  }

  // Nur die gezeichneten Pfade, nicht die in <defs>.
  const defsEnde = svg.indexOf("</defs>");
  const inhalt = defsEnde < 0 ? svg : svg.slice(defsEnde);
  const body = [];
  const detail = [];
  const muscles = [];
  for (const [tag] of inhalt.matchAll(/<path\b[^>]*>/g)) {
    const klasse = attribut(tag, "class");
    const d = attribut(tag, "d");
    if (/[^MLCZ0-9.,\s-]/.test(d)) throw new Error(`${datei}: unerwarteter Pfadbefehl in ${d.slice(0, 40)}`);
    if (klasse === "body") body.push(d);
    else if (klasse === "anatomy-detail") detail.push(d);
    else if (klasse === "muscle") {
      const eintrag = { muscle: attribut(tag, "data-muscle"), d };
      if (attribut(tag, "fill-rule") === "evenodd") eintrag.evenodd = true;
      const clip = attribut(tag, "clip-path")?.match(/^url\(#(.+)\)$/)?.[1];
      if (clip !== undefined) {
        if (rechtecke[clip]) eintrag.clip = rechtecke[clip];
        else if (clipPfade[clip]) eintrag.clipPfad = clip;
        else throw new Error(`${datei}: clipPath ${clip} fehlt`);
      }
      muscles.push(eintrag);
    } else throw new Error(`${datei}: Pfad ohne bekannte Klasse`);
  }
  if (body.length === 0 || muscles.length === 0) throw new Error(`${datei}: keine Pfade gefunden`);

  const genutzt = Object.fromEntries(
    Object.keys(clipPfade)
      .sort()
      .filter((id) => muscles.some((m) => m.clipPfad === id))
      .map((id) => [id, clipPfade[id]]),
  );
  return { viewBox, body, detail, muscles, clipPfade: genutzt };
}

const ausgabe = {
  hinweis:
    "Erzeugt von scripts/muskelmodell-json.mjs aus assets/muskelmodell (Revision 4). Nicht von Hand bearbeiten. Schematisches Modell, fachliche Freigabe offen.",
  lizenz: readFileSync(join(quelle, "LICENSE.txt"), "utf8").trim(),
};
for (const [modell, seiten] of Object.entries(dateien)) {
  ausgabe[modell] = { vorne: ansicht(seiten.vorne), hinten: ansicht(seiten.hinten) };
}

writeFileSync(ziel, JSON.stringify(ausgabe) + "\n");
console.log(`${ziel} geschrieben`);
