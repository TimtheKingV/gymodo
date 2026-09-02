/**
 * Die Antworttabelle des Suchers -- Spec 4 und TelefonZustaende.dc.html.
 *
 * Rein und ohne Netz, damit sie sich als Test lesen laesst: was der Sucher
 * antwortet, ist eine Produktentscheidung und keine Laufzeitfrage. Die
 * Verdikte kommen woertlich aus inspect_tag (0028).
 */

export type Verdikt =
  | "frei"
  | "vergeben"
  | "gesperrt"
  | "aushangschild"
  | "unbekannt";

export type Befund =
  | { verdikt: "frei"; batchCode: string; batchIndex: number }
  | { verdikt: "vergeben"; machineId: string; machineLabel: string }
  | { verdikt: "gesperrt" }
  | { verdikt: "aushangschild" }
  | { verdikt: "unbekannt" };

export type Antwort = {
  titel: string;
  text: string;
  /** null heisst: hier gibt es nichts zu tun, nur einen Weg zurueck. */
  hauptaktion: "verbinden" | "ersetzen" | null;
  ton: "gut" | "neutral" | "warnung";
};

export function antwortAuf(
  befund: Befund,
  geraetLabel: string,
  optionen: { geraetHatTag?: boolean } = {},
): Antwort {
  switch (befund.verdikt) {
    case "frei":
      return optionen.geraetHatTag
        ? {
            titel: "Tag erkannt",
            text: `Charge ${befund.batchCode} · Nummer ${befund.batchIndex}. An ${geraetLabel} klebt schon ein Tag — der alte wird dabei ungültig. Zieh ihn danach ab: er öffnet nichts mehr, aber er verwirrt.`,
            hauptaktion: "ersetzen",
            ton: "warnung",
          }
        : {
            titel: "Tag erkannt",
            text: `Charge ${befund.batchCode} · Nummer ${befund.batchIndex} · vorrätig, noch keinem Gerät zugeordnet. Ab dem Verbinden ist ${geraetLabel} für Mitglieder auffindbar.`,
            hauptaktion: "verbinden",
            ton: "gut",
          };

    // Keine Hauptaktion, und das ist Entscheidung 8: sonst verloere ein Geraet
    // seinen Tag, ohne dass jemand davorsteht.
    case "vergeben":
      return {
        titel: "Der Tag hängt schon woanders",
        text: `Dieser Tag gehört zu ${befund.machineLabel}. Ein vergebener Tag wird nicht mit einem Tap umgehängt. Nimm einen anderen aus der Packung.`,
        hauptaktion: null,
        ton: "neutral",
      };

    case "gesperrt":
      return {
        titel: "Gesperrt bleibt gesperrt",
        text: "Auch nach einem Neustart, auch nach einem Jahr. Der Eintrag steht als Nachweis weiter in der Liste. Nimm einen anderen aus der Packung.",
        hauptaktion: null,
        ton: "warnung",
      };

    // Eine Sackgasse mit genau einem Ausgang: das Schild ist ab der Lieferung
    // gueltig und gehoert an die Wand.
    case "aushangschild":
      return {
        titel: "Das ist ein Aushangschild",
        text: "Kein Gerätetag: dieses Schild gehört an die Wand. Wer es scannt, wird Mitglied — dafür ist es ab der Lieferung gültig, du musst nichts freischalten. Nimm einen Tag aus der Gerätepackung.",
        hauptaktion: null,
        ton: "neutral",
      };

    // Eine Antwort fuer zwei Faelle, und das ist Absicht (Spec 4): dieselbe
    // Regel, die join_studio_by_tag im Rumpf traegt.
    case "unbekannt":
      return {
        titel: "Der Tag gehört nicht zu diesem Studio",
        text: "Unbekannt oder aus einem fremden Studio. Neue Lieferung angekommen? Melde dich beim Betreiber.",
        hauptaktion: null,
        ton: "warnung",
      };
  }
}
