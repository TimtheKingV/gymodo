import type { StudioCatalog } from "@fitretro/domain";

/**
 * Was an einem Geraetemodell noch fehlt -- eine reine Ableitung, ohne
 * Datenbank und ohne React.
 *
 * Eigene Datei und nicht catalog.ts nebenan: catalog.ts zieht den
 * Server-Client mit (`@/lib/supabase/server`), und damit waere diese
 * Rechnung nur noch mit laufendem Supabase pruefbar. Dasselbe Muster wie
 * kurse/woche.ts und einrichten/befund.ts, die aus demselben Grund neben
 * ihren Seiten liegen.
 */
export type OffenerPunkt = {
  /** Was fehlt -- als Tatsache, nicht als Vorwurf. */
  titel: string;
  /** Was es kostet, dass es fehlt. Ein Satz, kein Halbsatz. */
  grund: string;
  href: string;
  label: string;
  /** Ein Modell ohne Uebung ist unbenutzbar; eine Uebung ohne Video ist
      nutzbar, nur ohne Anleitung. Die Reihenfolge der Liste folgt dem. */
  art: "blockiert" | "unvollstaendig";
};

/**
 * Was an einem Modell noch fehlt, in der Reihenfolge, in der es
 * aufeinander aufbaut: ohne Foto kein Wiedererkennen, ohne Einstellung
 * nichts einzustellen, ohne Uebung nichts zu tun, ohne Geraet niemand im
 * Raum, ohne Tag nicht auffindbar.
 *
 * Steht hier und nicht in der Seite, weil drei Stellen dieselbe Liste
 * brauchen: das Band ueber den Modellreitern, die Zeile in der
 * Modellliste und (spaeter) der Ueberblick. Die Halle zaehlt denselben
 * Mangel heute noch einmal selbst (einrichten/page.tsx, `mangel`) -- das
 * bleibt vorerst, weil sie ihn anders formuliert und anders sortiert.
 */
export function offenePunkte(
  studioId: string,
  modell: StudioCatalog["models"][number],
): OffenerPunkt[] {
  const basis = `/portal/${studioId}/geraete/${modell.id}`;
  const punkte: OffenerPunkt[] = [];

  if (modell.photoPath === null) {
    punkte.push({
      titel: "Kein Foto",
      grund:
        "Nach dem Scan ist das Gerät nicht von seinem baugleichen Nachbarn zu unterscheiden.",
      href: basis,
      label: "Foto hochladen",
      art: "blockiert",
    });
  }

  if (modell.settingDefinitions.length === 0) {
    punkte.push({
      titel: "Keine Einstellungen",
      grund: "Das Mitglied hat am Gerät nichts einzustellen und nichts zu merken.",
      href: `${basis}/einstellungen`,
      label: "Einstellung anlegen",
      art: "blockiert",
    });
  }

  if (modell.exercises.length === 0) {
    punkte.push({
      titel: "Keine Übung",
      grund: "Der Geräte-Screen zeigt dann nur den Namen. Eine reicht zum Anfangen.",
      href: `${basis}/uebungen`,
      label: "Übung anlegen",
      art: "blockiert",
    });
  }

  const aktive = modell.machines.filter((geraet) => geraet.status === "active");
  const ohneTag = aktive.filter((geraet) => geraet.activeTagCount === 0);

  if (aktive.length === 0) {
    punkte.push({
      titel: "Kein Gerät im Raum",
      grund: "Das Modell beschreibt einen Typ. Erst ein Gerät steht wirklich da.",
      href: `${basis}/instanzen`,
      label: "Gerät anlegen",
      art: "blockiert",
    });
  } else if (ohneTag.length > 0) {
    punkte.push({
      titel:
        ohneTag.length === 1
          ? `Gerät ${ohneTag[0]!.label} ohne Tag`
          : `${ohneTag.length} Geräte ohne Tag`,
      grund: "Ohne aktiven Tag findet ein Mitglied das Gerät nicht.",
      // Bei genau einem Geraet direkt vor das Geraet, sonst auf den Reiter:
      // welcher Tag an welches Geraet gehoert, entscheidet der Scan davor.
      href:
        ohneTag.length === 1
          ? `/portal/${studioId}/einrichten/geraet/${ohneTag[0]!.id}/tag`
          : `${basis}/instanzen`,
      label: ohneTag.length === 1 ? "Tag scannen" : "Geräte ansehen",
      art: "blockiert",
    });
  }

  const ohneVideo = modell.exercises.filter((uebung) => !uebung.hasVideo);
  if (ohneVideo.length > 0) {
    punkte.push({
      titel:
        ohneVideo.length === 1
          ? "1 Übung ohne Einweisungsvideo"
          : `${ohneVideo.length} Übungen ohne Einweisungsvideo`,
      grund: "Nutzbar, nur ohne Anleitung.",
      href: `${basis}/uebungen`,
      label: "Video nachtragen",
      art: "unvollstaendig",
    });
  }

  return punkte;
}
