/**
 * Welche Quelldatei zeigt gerade, was im Browser steht?
 *
 * Auf iOS meldet das ein Modifier an jeder Screen-Wurzel (`#filePath`). Im
 * App-Router steht dieselbe Angabe schon im Verzeichnisbaum: eine URL fuehrt
 * genau auf eine `page.tsx`, die Huellen darueber sind ihre Ebenen. Deshalb
 * traegt keine Seite eine Markierung.
 *
 * Der Baum kommt als fertige Karte (`routenkarte.mjs`, zur Bauzeit gelesen
 * und per DefinePlugin ins Buendel gelegt). Diese Datei rechnet nur noch:
 * keine Dateisystemzugriffe, laeuft deshalb auch im Browser -- und der
 * braucht sie, seit die Sitzung ohne Server auskommt.
 *
 * Aufgeloest wird nur gegen das, was in der Karte steht; aus einem Segment
 * wird nie ein Pfad gebaut. Ein `..` in der URL kann so nichts erreichen.
 */

import type { Screen } from "./format";

export type Routenknoten = {
  /** Repo-relativer Pfad der `page.tsx`, falls dieser Knoten eine Seite ist. */
  seite?: string;
  /** Repo-relativer Pfad der `layout.tsx`, falls dieser Knoten eine Huelle hat. */
  huelle?: string;
  kinder: Record<string, Routenknoten>;
};

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

type Zustand = {
  knoten: Routenknoten;
  muster: string[];
  stapel: string[];
  parameter: Record<string, string>;
};

/**
 * Der `screen`-Teil eines Eintrags: die Quelldatei samt Ebenen, dazu als
 * Kontext die aufgeloesten Segmente der Route, die Abfrage der URL und was
 * der Aufrufer sonst noch mitgibt.
 */
export function screenBauen(
  karte: Routenknoten | null,
  ort: { pfad: string; suche?: string; kontext?: Record<string, string> },
): Screen | null {
  const treffer = seiteFinden(karte, ort.pfad);
  if (!treffer) return null;

  const context: Record<string, string> = { ...treffer.parameter };
  for (const [schluessel, wert] of new URLSearchParams(ort.suche ?? "")) {
    context[schluessel] = wert;
  }
  for (const [schluessel, wert] of Object.entries(ort.kontext ?? {})) {
    context[schluessel] = wert;
  }

  return { name: treffer.name, file: treffer.datei, stack: treffer.stapel, context };
}

export function seiteFinden(karte: Routenknoten | null, pfad: string): Seitentreffer | null {
  if (!karte) return null;
  const segmente = pfad.split("/").filter((teil) => teil.length > 0);
  return suchen({ knoten: karte, muster: [], stapel: [], parameter: {} }, segmente);
}

function suchen(zustand: Zustand, segmente: string[]): Seitentreffer | null {
  const stapel = zustand.knoten.huelle ? [...zustand.stapel, zustand.knoten.huelle] : zustand.stapel;
  const namen = Object.keys(zustand.knoten.kinder);
  const gruppen = namen.filter((name) => name.startsWith("(") && name.endsWith(")"));

  if (segmente.length === 0) {
    const seite = zustand.knoten.seite;
    if (seite) {
      return {
        datei: seite,
        name: zustand.muster.length > 0 ? zustand.muster.join("/") : "start",
        stapel: [...stapel, seite],
        parameter: zustand.parameter,
      };
    }
    // Eine Gruppe traegt keine eigene URL-Ebene: /portal/s_1 liegt in
    // (schreibtisch), die Seite steht also erst eine Ebene tiefer.
    return ersterTreffer(gruppen, (gruppe) =>
      suchen({ ...zustand, knoten: kind(zustand, gruppe), stapel }, []),
    );
  }

  const segment = segmente[0];
  const rest = segmente.slice(1);
  if (segment === undefined) return null;

  // Reihenfolge wie im Router: woertlich schlaegt Gruppe schlaegt dynamisch
  // schlaegt Sammelsegment.
  if (!segment.startsWith("(") && namen.includes(segment)) {
    const treffer = suchen(
      {
        knoten: kind(zustand, segment),
        muster: [...zustand.muster, segment],
        stapel,
        parameter: zustand.parameter,
      },
      rest,
    );
    if (treffer) return treffer;
  }

  const ausGruppe = ersterTreffer(gruppen, (gruppe) =>
    suchen({ ...zustand, knoten: kind(zustand, gruppe), stapel }, segmente),
  );
  if (ausGruppe) return ausGruppe;

  const dynamisch = namen.filter((name) => /^\[[^.\]]+\]$/.test(name));
  const ausDynamisch = ersterTreffer(dynamisch, (name) =>
    suchen(
      {
        knoten: kind(zustand, name),
        muster: [...zustand.muster, name],
        stapel,
        parameter: { ...zustand.parameter, [name.slice(1, -1)]: segment },
      },
      rest,
    ),
  );
  if (ausDynamisch) return ausDynamisch;

  const sammel = namen.filter((name) => /^\[\[?\.\.\..+?\]\]?$/.test(name));
  return ersterTreffer(sammel, (name) => {
    const schluessel = name.replace(/^\[+\.\.\./, "").replace(/\]+$/, "");
    return suchen(
      {
        knoten: kind(zustand, name),
        muster: [...zustand.muster, name],
        stapel,
        parameter: { ...zustand.parameter, [schluessel]: segmente.join("/") },
      },
      [],
    );
  });
}

function kind(zustand: Zustand, name: string): Routenknoten {
  return zustand.knoten.kinder[name] ?? { kinder: {} };
}

function ersterTreffer<T>(werte: T[], versuch: (wert: T) => Seitentreffer | null): Seitentreffer | null {
  for (const wert of werte) {
    const treffer = versuch(wert);
    if (treffer) return treffer;
  }
  return null;
}
