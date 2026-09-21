import { readdirSync } from "node:fs";
import path from "node:path";

/**
 * Welche Quelldatei zeigt gerade, was im Browser steht?
 *
 * Auf iOS meldet das ein Modifier an jeder Screen-Wurzel (`#filePath`). Im
 * App-Router steht dieselbe Angabe schon im Verzeichnisbaum: eine URL fuehrt
 * genau auf eine `page.tsx`, die Huellen darueber sind ihre Ebenen. Deshalb
 * traegt keine Seite eine Markierung -- die Zuordnung passiert beim Sichern
 * auf dem Server, aus dem Pfad.
 *
 * Aufgeloest wird nur gegen das, was `readdir` liefert; aus einem Segment
 * wird nie ein Pfad gebaut. Ein `..` in der URL kann so nicht aus dem
 * App-Verzeichnis herausfuehren.
 */

export type Seitentreffer = {
  /** Repo-relativ, z. B. `apps/web/app/portal/[studioId]/(schreibtisch)/geraete/page.tsx`. */
  datei: string;
  /** Routenmuster ohne Klammergruppen, z. B. `portal/[studioId]/geraete`. */
  name: string;
  /** Huellen von aussen nach innen, zuletzt die Seite selbst. */
  stapel: string[];
  /** Die aufgeloesten dynamischen Segmente, z. B. `{ studioId: "s_1" }`. */
  parameter: Record<string, string>;
};

const ENDUNGEN = [".tsx", ".ts", ".jsx", ".js"];

type Zustand = {
  verzeichnis: string;
  muster: string[];
  stapel: string[];
  parameter: Record<string, string>;
};

export function seiteFinden(
  pfad: string,
  optionen: { wurzel: string; praefix: string },
): Seitentreffer | null {
  const segmente = pfad.split("/").filter((teil) => teil.length > 0);
  return suchen(
    { verzeichnis: optionen.wurzel, muster: [], stapel: [], parameter: {} },
    segmente,
    optionen,
  );
}

function suchen(
  zustand: Zustand,
  segmente: string[],
  optionen: { wurzel: string; praefix: string },
): Seitentreffer | null {
  const eintraege = lesen(zustand.verzeichnis);
  if (!eintraege) return null;

  const stapel = [...zustand.stapel];
  const huelle = datei(eintraege, "layout");
  if (huelle) stapel.push(relativ(path.join(zustand.verzeichnis, huelle), optionen));

  const gruppen = eintraege.filter((name) => name.startsWith("(") && name.endsWith(")"));

  if (segmente.length === 0) {
    const seite = datei(eintraege, "page");
    if (seite) {
      return {
        datei: relativ(path.join(zustand.verzeichnis, seite), optionen),
        name: zustand.muster.length > 0 ? zustand.muster.join("/") : "start",
        stapel: [...stapel, relativ(path.join(zustand.verzeichnis, seite), optionen)],
        parameter: zustand.parameter,
      };
    }
    // Eine Gruppe traegt keine eigene URL-Ebene: /portal/s_1 liegt in
    // (schreibtisch), die Seite steht also erst eine Ebene tiefer.
    return ersterTreffer(gruppen, (gruppe) =>
      suchen({ ...zustand, verzeichnis: path.join(zustand.verzeichnis, gruppe), stapel }, [], optionen),
    );
  }

  const segment = segmente[0];
  const rest = segmente.slice(1);
  if (segment === undefined) return null;

  // Reihenfolge wie im Router: woertlich schlaegt Gruppe schlaegt dynamisch
  // schlaegt Sammelsegment.
  const woertlich = eintraege.find((name) => name === segment && istVerzeichnis(zustand.verzeichnis, name));
  if (woertlich) {
    const treffer = suchen(
      {
        verzeichnis: path.join(zustand.verzeichnis, woertlich),
        muster: [...zustand.muster, woertlich],
        stapel,
        parameter: zustand.parameter,
      },
      rest,
      optionen,
    );
    if (treffer) return treffer;
  }

  const ausGruppe = ersterTreffer(gruppen, (gruppe) =>
    suchen({ ...zustand, verzeichnis: path.join(zustand.verzeichnis, gruppe), stapel }, segmente, optionen),
  );
  if (ausGruppe) return ausGruppe;

  const dynamisch = eintraege.filter((name) => /^\[[^.\]]+\]$/.test(name));
  const ausDynamisch = ersterTreffer(dynamisch, (name) =>
    suchen(
      {
        verzeichnis: path.join(zustand.verzeichnis, name),
        muster: [...zustand.muster, name],
        stapel,
        parameter: { ...zustand.parameter, [name.slice(1, -1)]: segment },
      },
      rest,
      optionen,
    ),
  );
  if (ausDynamisch) return ausDynamisch;

  const sammel = eintraege.filter((name) => /^\[\[?\.\.\..+?\]\]?$/.test(name));
  return ersterTreffer(sammel, (name) => {
    const schluessel = name.replace(/^\[+\.\.\./, "").replace(/\]+$/, "");
    return suchen(
      {
        verzeichnis: path.join(zustand.verzeichnis, name),
        muster: [...zustand.muster, name],
        stapel,
        parameter: { ...zustand.parameter, [schluessel]: segmente.join("/") },
      },
      [],
      optionen,
    );
  });
}

function ersterTreffer<T>(werte: T[], versuch: (wert: T) => Seitentreffer | null): Seitentreffer | null {
  for (const wert of werte) {
    const treffer = versuch(wert);
    if (treffer) return treffer;
  }
  return null;
}

function lesen(verzeichnis: string): string[] | null {
  try {
    return readdirSync(verzeichnis);
  } catch {
    return null;
  }
}

function istVerzeichnis(elternteil: string, name: string): boolean {
  try {
    return readdirSync(path.join(elternteil, name)) !== null;
  } catch {
    return false;
  }
}

function datei(eintraege: string[], basis: string): string | undefined {
  return ENDUNGEN.map((endung) => `${basis}${endung}`).find((name) => eintraege.includes(name));
}

function relativ(absolut: string, optionen: { wurzel: string; praefix: string }): string {
  const teil = path.relative(optionen.wurzel, absolut).split(path.sep).join("/");
  return `${optionen.praefix}/${teil}`;
}
