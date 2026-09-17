import type { StudioCatalog } from "@fitretro/domain";

type Einstellung = StudioCatalog["models"][number]["settingDefinitions"][number];

/** Mehr als das zeigt keine Zeile -- danach steht die Zahl der Rasten. */
const SICHTBAR = 6;

export type Rasten =
  | { art: "liste"; werte: string[]; anzahl: number; gekuerzt: boolean }
  /** Ein Bereich ohne Schrittweite laesst sich nicht aufzaehlen -- dann
      bleibt nur die Spanne, und genau das sagt der Satz. */
  | { art: "spanne"; text: string };

/** Deutsche Schreibweise, und 2,5 bleibt 2,5 statt 2.5. */
function zahl(wert: number): string {
  return wert.toLocaleString("de-DE", { maximumFractionDigits: 2 });
}

/**
 * Was ein Mitglied an dieser Einstellung tatsaechlich waehlen kann.
 *
 * Der Reiter zeigte bislang die Definition -- "1 bis 10 in Schritten von
 * 1". Das ist die Eingabe des Trainers, nicht die Erfahrung des
 * Mitglieds: Ob die Kombination am Geraet sinnvoll rastet, sah er erst am
 * Geraet. Hier stehen die Rasten selbst.
 *
 * Bewusst KEINE Nachbildung des Rads aus der Member-App: das Portal kann
 * nur seine eigene Webkomponente zeigen, und die ist nicht das, was auf
 * dem Telefon steht. Eine Vorschau, die "so sieht es am Geraet aus"
 * verspricht und etwas anderes zeigt, waere schlechter als keine. Die
 * Werte dagegen stimmen genau.
 */
export function rasten(einstellung: Einstellung): Rasten {
  if (einstellung.kind === "enum") {
    const werte = einstellung.allowedValues ?? [];
    return {
      art: "liste",
      werte: werte.slice(0, SICHTBAR),
      anzahl: werte.length,
      gekuerzt: werte.length > SICHTBAR,
    };
  }

  const { minValue, maxValue, stepValue, unit } = einstellung;
  const einheit = unit ? ` ${unit}` : "";

  if (minValue === null || maxValue === null || !stepValue || stepValue <= 0) {
    const von = minValue === null ? "?" : zahl(minValue);
    const bis = maxValue === null ? "?" : zahl(maxValue);
    return {
      art: "spanne",
      text:
        stepValue && stepValue > 0
          ? `${von} bis ${bis} in Schritten von ${zahl(stepValue)}${einheit}`
          : `${von} bis ${bis}${einheit}`,
    };
  }

  // Aufaddieren statt min + i * step: bei 2,5er-Schritten summieren sich
  // sonst Fliesskommareste sichtbar auf (0,30000000000000004).
  const werte: string[] = [];
  const anzahl = Math.floor((maxValue - minValue) / stepValue) + 1;
  for (let i = 0; i < Math.min(anzahl, SICHTBAR); i += 1) {
    werte.push(zahl(Math.round((minValue + i * stepValue) * 100) / 100) + einheit);
  }

  return { art: "liste", werte, anzahl, gekuerzt: anzahl > SICHTBAR };
}

/** Ein Satz aus dem Ergebnis -- fuer die Zeile, die keinen Platz fuer eine
    Aufzaehlung mit eigenem Layout hat. */
export function rastenText(einstellung: Einstellung): string {
  const ergebnis = rasten(einstellung);
  if (ergebnis.art === "spanne") return ergebnis.text;
  if (ergebnis.anzahl === 0) return "Keine Werte hinterlegt";
  const kern = ergebnis.werte.join(" · ");
  if (!ergebnis.gekuerzt) {
    return `${kern} · ${ergebnis.anzahl} ${ergebnis.anzahl === 1 ? "Raste" : "Rasten"}`;
  }
  return `${kern} … · ${ergebnis.anzahl} Rasten`;
}
