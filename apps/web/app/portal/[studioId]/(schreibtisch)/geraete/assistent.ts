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
