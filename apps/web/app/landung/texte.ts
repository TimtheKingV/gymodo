/**
 * Alle Texte der Landeseite an einer Stelle (Spec 5, Designsystem 10).
 * Jede Aussage ueber das Produkt traegt ihren Beleg im Kommentar -- die
 * Seite verspricht nichts, was die App nicht tut.
 */
import type { Frage } from "./Fragen";
import type { Pille } from "./OhneMit";
import type { Schritt } from "./Schritte";

export const MARKE = "Gymtavo";

export const HELD = {
  titel: "Nie wieder raten am Gerät.",
  // Beleg: Geraete-Screen der App zeigt Einstellwerte, letzte Saetze und
  // Einweisungsvideos des Studios (designsystem.md 7, t/[token]/page.tsx).
  vorspann:
    "Halte dein iPhone an das Gerät. Du siehst deine Einstellung, deine letzten Sätze und die Einweisung deines Studios.",
  aktion: "App laden",
  nebenlink: "Wie das funktioniert",
  bild: {
    src: "/landung/geraet.png",
    alt: "Der Geräte-Screen der App mit Einstellwerten und den letzten Sätzen",
  },
} as const;

// Belege: "Einweisung auch ohne App" -- t/[token]/page.tsx zeigt Videos
// oeffentlich, Fussnote "funktioniert auf jedem Geraet und ohne App".
// "an jedem Geraet mit Tag" -- Einstellwerte haengen am Geraet (Spec M1).
export const FAKTEN = [
  "Ein Tap statt Zettel",
  "Einweisung auch ohne App",
  "Deine Werte an jedem Gerät mit Tag",
] as const;

// Positionen in Prozent der Buehne (mobil gemessen im Prototyp vom 3.10.).
export const OHNE_MIT: { titel: string; ohne: readonly Pille[]; mit: readonly string[] } = {
  titel: "Weißt du noch, wie du das Gerät eingestellt hast?",
  ohne: [
    { text: "Wie viele Wiederholungen?", x: 56, y: 6 },
    { text: "Sitz 4 oder 5?", x: 26, y: 14 },
    { text: "Letztes Mal 40 oder 45 kg?", x: 58, y: 24 },
    { text: "Wie ging die Übung?", x: 30, y: 36 },
    { text: "Wo ist der Zettel?", x: 72, y: 44 },
    { text: "3 oder 4 Sätze?", x: 24, y: 54 },
    { text: "Lehne verstellt?", x: 66, y: 62 },
    { text: "Trainer gerade frei?", x: 36, y: 72 },
    { text: "Notizen-App?", x: 76, y: 80 },
    { text: "Griff oben oder unten?", x: 40, y: 88 },
  ],
  // Beleg "Vorschlag +2,5 kg": Zahlformat.swift / designsystem.md 10.
  mit: ["Sitz 5 · Lehne 3", "Zuletzt 42,5 kg × 10", "Vorschlag +2,5 kg", "Einweisung ansehen"],
};

export const SCHRITTE_TITEL = "So geht's";
export const SCHRITTE: readonly Schritt[] = [
  {
    titel: "Tippen",
    text: "Halte dein iPhone an den Tag am Gerät.",
    bild: { src: "/landung/tippen.png", alt: "Das Scan-Fenster der App mit NFC und QR-Code" },
  },
  {
    titel: "Trainieren",
    text: "Deine Einstellung steht schon da. Du bestätigst nur deine Sätze.",
    bild: { src: "/landung/geraet.png", alt: "Der Geräte-Screen mit Einstellwerten und Satzrad" },
  },
  {
    // Beleg: Verlauf/ und Verlauf/HomeZiele.swift in der App.
    titel: "Weiterkommen",
    text: "Verlauf und Ziele zeigen dir, wo du stehst.",
    bild: { src: "/landung/verlauf.png", alt: "Der Verlauf eines Geräts mit den letzten Trainings" },
  },
];

export const CTA = {
  titel: "Probier es am nächsten Gerät.",
  // E3: kostenlos fuer Mitglieder, das Studio zahlt.
  text: "Die App ist kostenlos. Du brauchst nur ein Studio, das Gymtavo nutzt.",
  aktion: "App laden",
} as const;

export const VERLAUF = {
  titel: "Dein Fortschritt, ohne Rechnerei.",
  karten: [
    {
      titel: "Jedes Gerät mit Verlauf",
      text: "Was du an einem Gerät bestätigt hast, steht beim nächsten Mal wieder da.",
    },
    {
      titel: "Ziele, die du selbst setzt",
      text: "Du legst fest, worauf du hinarbeitest, und siehst, wo du stehst.",
    },
    {
      // Beleg: Kurse seit Phase 4 (designsystem.md 11), Text wie t/[token].
      titel: "Kurse am selben Ort",
      text: "Wochenplan, Anmeldung und Warteliste deines Studios in derselben App.",
    },
  ],
} as const;

export const PRODUKTGRENZE =
  "Gymtavo speichert nur, was du bestätigst. Mit Sensor zählt Gymtavo deine Wiederholungen mit — du siehst die Zahl und entscheidest. Einweisungsvideos und Einstellhinweise sind Inhalte deines Studios, keine Trainings- oder Gesundheitsempfehlung von Gymtavo.";

// "Wo liegen meine Daten?" fehlt bewusst, bis die Antwort belegt ist (Spec 5, [pruefen]).
export const FRAGEN: readonly Frage[] = [
  { frage: "Kostet die App etwas?", antwort: "Nein. Die App ist kostenlos, dein Studio nutzt Gymtavo." },
  {
    frage: "Brauche ich ein Studio mit Gymtavo?",
    antwort:
      "Ja. Einstellwerte und Einweisungen kommen von deinem Studio. Ist es noch nicht dabei, frag an der Theke nach.",
  },
  {
    frage: "Gibt es Gymtavo für Android?",
    antwort:
      "Die App gibt es zurzeit nur für iPhone. Die Einweisung am Gerät öffnet sich aber auf jedem Handy, auch ohne App.",
  },
  { frage: "Was misst Gymtavo?", antwort: PRODUKTGRENZE },
  {
    // E1: Sensor nur als Antwort, ohne Termin und ohne Formular.
    frage: "Wann kommt der Sensor?",
    antwort: "Er ist in Entwicklung. Einen Termin nennen wir erst, wenn er feststeht.",
  },
];

export const KAUFLEISTE = {
  titel: MARKE,
  merkmale: ["Tap am Gerät", "Deine Werte", "Für iPhone"],
  aktion: "App laden",
} as const;
