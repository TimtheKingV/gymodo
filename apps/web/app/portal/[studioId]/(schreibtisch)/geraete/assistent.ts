/**
 * "Gerät hinzufügen" als gefuehrter Ablauf (Testnotiz 23.09., #7): statt
 * eines Formulars ueber der Geraeteliste eine eigene Strecke, die sich auf
 * das neue Modell beschraenkt -- Stammdaten, Einstellungen, Uebungen,
 * einzelne Geraete, je mit "Weiter" unten.
 *
 * Die Schritte 2 bis 4 sind die bestehenden Reiter des Modells, nicht
 * nachgebaute Seiten: `?neu=1` schaltet im Modell-Layout Reiterleiste und
 * "Noch zu tun" gegen Schrittleiste und Fussleiste um (ModellRahmen.tsx).
 * Schritt 1 steht vor dem Anlegen unter /geraete/neu, nach dem Anlegen
 * (auf "Zurück") als Stammdaten-Reiter desselben Modells.
 */

export const ASSISTENT_PARAM = "neu";
export const ASSISTENT_SCHRITTE = 4;

export type AssistentSchritt = {
  nummer: number;
  titel: string;
  /** null im ersten Schritt -- dahinter liegt nur das Anlegen selbst. */
  zurueck: string | null;
  weiter: { href: string; label: string };
};

/** Die Reiter in Aufbaureihenfolge; `null` ist das Segment der Stammdaten. */
const REIHE: { segment: string | null; titel: string; weiterLabel: string }[] = [
  { segment: null, titel: "Stammdaten", weiterLabel: "Weiter zu den Einstellungen" },
  { segment: "einstellungen", titel: "Einstellungen", weiterLabel: "Weiter zu den Übungen" },
  { segment: "uebungen", titel: "Übungen", weiterLabel: "Weiter zu den Geräten" },
  { segment: "instanzen", titel: "Einzelne Geräte", weiterLabel: "Fertig" },
];

function adresse(studioId: string, modelId: string, segment: string | null): string {
  const basis = `/portal/${studioId}/geraete/${modelId}`;
  return `${segment === null ? basis : `${basis}/${segment}`}?${ASSISTENT_PARAM}=1`;
}

export function assistentSchritt(
  studioId: string,
  modelId: string,
  segment: string | null,
): AssistentSchritt | null {
  const index = REIHE.findIndex((eintrag) => eintrag.segment === segment);
  if (index === -1) return null;

  const eintrag = REIHE[index]!;
  const vorher = REIHE[index - 1];
  const nachher = REIHE[index + 1];

  return {
    nummer: index + 1,
    titel: eintrag.titel,
    zurueck: vorher ? adresse(studioId, modelId, vorher.segment) : null,
    weiter: {
      // Nach dem letzten Schritt zurueck an den Anfang der Strecke: die
      // Geraeteliste, auf der das neue Modell jetzt steht.
      href: nachher
        ? adresse(studioId, modelId, nachher.segment)
        : `/portal/${studioId}/geraete`,
      label: eintrag.weiterLabel,
    },
  };
}

/** Wohin es nach dem Anlegen (Schritt 1) geht. */
export function assistentStart(studioId: string, modelId: string): string {
  return adresse(studioId, modelId, REIHE[1]!.segment);
}

/**
 * Ob "Weiter" im Ablauf schon frei ist (Testnotiz 23.09., zweite Sitzung,
 * #1 und #5): `null` heisst frei, sonst steht der Satz an seiner Stelle.
 *
 * Einstellungen: erst mit einer gespeicherten -- und nicht, solange das
 * Formular offen ist, denn ein Klick auf "Weiter" wuerde das Getippte
 * wortlos verwerfen. Uebungen: erst ab einer angelegten. Das offene
 * Formular zaehlt dort nicht, weil es nach dem Anlegen fuer die naechste
 * Uebung offen bleibt (Hinzufuegen.tsx).
 */
export function weiterSperre(
  segment: string | null,
  stand: { einstellungen: number; uebungen: number; formularOffen: boolean },
): string | null {
  if (segment === "einstellungen") {
    if (stand.einstellungen === 0) return "Zuerst eine Einstellung speichern.";
    if (stand.formularOffen) return "Erst speichern oder abbrechen.";
  }
  if (segment === "uebungen" && stand.uebungen === 0) return "Zuerst eine Übung anlegen.";
  return null;
}

export type NeuAnsicht = "frage" | "typ" | "exemplar";

/**
 * Was /geraete/neu zeigt (Testnotiz 25.09., #7). Bisher kam das zweite
 * gleiche Geraet nur ueber den letzten Reiter "Einzelne Geräte" des Modells
 * dazu. Jetzt fragt der Ablauf zuerst, ob es den Typ schon gibt -- aber nur,
 * wenn es ueberhaupt einen gibt: ohne Modell waere "vorhandenen Typ waehlen"
 * eine leere Liste.
 */
export function neuAnsicht(art: string | undefined, modellAnzahl: number): NeuAnsicht {
  if (modellAnzahl === 0) return "typ";
  if (art === "typ" || art === "exemplar") return art;
  return "frage";
}
