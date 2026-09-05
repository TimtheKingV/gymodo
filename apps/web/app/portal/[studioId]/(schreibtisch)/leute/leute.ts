import { DomainError, listStudioMembers, type StudioMember } from "@fitretro/domain";
import { createServerSupabaseClient } from "@/lib/supabase/server";

/**
 * Der gemeinsame Rumpf der beiden Leute-Reiter (Aufgabe 19).
 *
 * Beide Reiter -- Mitglieder (page.tsx) und Mitarbeiter (mitarbeiter/
 * page.tsx) -- brauchen dieselben vier Dinge: die nach Rolle geteilte
 * Liste, den eigenen Nutzer, die Studio-Zeitzone und die Sperre fuer
 * einfache Mitglieder. Ein layout.tsx waere der naheliegende Ort, kommt
 * hier aber nicht in Frage: Layouts kennen ihr aktives Kindsegment nicht
 * (Next-Doku zu useSelectedLayoutSegment), und der Reiter braucht genau
 * das. Am Modell (Aufgabe 16) kostete das einen Client-Rand; hier ist
 * jede Seite ihre eigene Server-Komponente und weiss ohne Browser, welche
 * sie ist -- `aktiv` ist eine Konstante. Der gemeinsame Teil steht
 * deshalb in diesem Modul und nicht in einem Layout.
 */

/**
 * Ab wie vielen Zeilen die Liste gekuerzt wird (LeuteMitglieder.dc.html
 * zeigt drei von 24 und danach "… 21 weitere").
 *
 * Acht, nicht drei: drei ist am Artboard eine Zeichnung, kein Grenzwert.
 * Zwei Gruende, beide gemessen am 5. September an einem Studio mit zwoelf
 * Mitgliedern, 1280x900:
 *
 * Nach unten -- acht Zeilen (je ~66 px) stehen zusammen mit Titel,
 * Vorspann, Reiter und Abschnittskopf im ERSTEN Bildschirm, und der
 * Ausklapplink "Alle anzeigen" steht bei y = 851 noch darin. Bei zwoelf
 * waere er es nicht mehr, und ein Ausklapplink, den man erst
 * herunterscrollen muss, kuerzt nichts.
 *
 * Nach oben -- ein junges Studio bekommt die Kuerzung damit gar nicht
 * erst zu sehen. Bei drei saehe ein Studio mit fuenf Mitgliedern eine
 * Kuerzung, die zwei Zeilen versteckt und dafuer eine Zeile Bedienung
 * kostet.
 */
export const KUERZUNG_AB = 8;

export type LeuteDaten = {
  mitglieder: StudioMember[];
  mitarbeiter: StudioMember[];
  /** Die eigene Nutzer-ID -- Befund 22: die eigene Zeile traegt keinen Knopf. */
  eigeneId: string | null;
  /** Designsystem 10: Zeitangaben in der Studio-Zeitzone, nicht der des Servers. */
  zeitzone: string;
  /** Ein einfaches Mitglied darf die Liste nicht sehen (requireStudioStaff). */
  keinRecht: boolean;
  fehler: string | null;
};

export async function ladeLeute(studioId: string): Promise<LeuteDaten> {
  const client = await createServerSupabaseClient();

  // Wie einstellungen/konto/page.tsx: der eigene Nutzer kommt aus
  // auth.getUser(), nicht aus der Mitgliederliste -- die kennt nur
  // userId und email, aber nicht, wer gerade davorsitzt.
  const {
    data: { user },
  } = await client.auth.getUser();

  const { data: studio } = await client
    .from("studios")
    .select("timezone")
    .eq("id", studioId)
    .maybeSingle<{ timezone: string }>();

  let alle: StudioMember[] = [];
  let keinRecht = false;
  let fehler: string | null = null;
  try {
    alle = await listStudioMembers(client, studioId);
  } catch (e) {
    // requireStudioStaff (in listStudioMembers) meldet ein einfaches
    // Mitglied mit "unauthorized" -- das Layout prueft nur Mitgliedschaft,
    // nicht Rolle, also muss diese Seite sich selbst sperren.
    if (e instanceof DomainError && e.code === "unauthorized") {
      keinRecht = true;
    } else {
      fehler = e instanceof DomainError ? e.message : "Die Liste ließ sich nicht laden.";
    }
  }

  return {
    // Beide Zahlen kommen aus DIESEM einen Aufruf und werden nur geteilt --
    // die Reiterbeschriftung nennt sie auf beiden Reitern gleich, ohne die
    // Liste ein zweites Mal zu holen.
    mitglieder: alle.filter((person) => person.role === "member"),
    mitarbeiter: alle.filter((person) => person.role !== "member"),
    eigeneId: user?.id ?? null,
    zeitzone: studio?.timezone ?? "Europe/Berlin",
    keinRecht,
    fehler,
  };
}

/**
 * Die beiden Reitereintraege. Die Zahl steht in der Beschriftung selbst
 * ("Mitglieder (24)"), nicht als `zusatz` darunter wie am Modell --
 * so zeichnen es beide Leute-Artboards, und eine Zahl in Klammern hinter
 * einem Wort ist kein zweiter Informationsrang.
 */
export function leuteReiter(
  studioId: string,
  daten: LeuteDaten,
  aktiv: "mitglieder" | "mitarbeiter",
) {
  return [
    {
      href: `/portal/${studioId}/leute`,
      label: `Mitglieder (${daten.mitglieder.length})`,
      aktiv: aktiv === "mitglieder",
    },
    {
      href: `/portal/${studioId}/leute/mitarbeiter`,
      label: `Mitarbeiter (${daten.mitarbeiter.length})`,
      aktiv: aktiv === "mitarbeiter",
    },
  ];
}

/** "Seit Di., 25. August 2026" -- der Wortlaut aus beiden Artboards. */
export function seit(iso: string, zeitzone: string): string {
  const datum = new Date(iso).toLocaleDateString("de-DE", {
    weekday: "short",
    day: "numeric",
    month: "long",
    year: "numeric",
    timeZone: zeitzone,
  });
  return `Seit ${datum}`;
}

/**
 * Kuerzt eine Liste serverseitig. Kein Client-Rand, kein Zustand, kein
 * zweiter Rundlauf: der volle Stand steht unter `?alle=1`, und der Link
 * dorthin ist ein gewoehnlicher Link.
 */
export function kuerzen<T>(
  alle: T[],
  alleZeigen: boolean,
): { sichtbar: T[]; weitere: number } {
  if (alleZeigen || alle.length <= KUERZUNG_AB) {
    return { sichtbar: alle, weitere: 0 };
  }
  return { sichtbar: alle.slice(0, KUERZUNG_AB), weitere: alle.length - KUERZUNG_AB };
}
