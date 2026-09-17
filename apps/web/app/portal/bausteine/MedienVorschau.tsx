import styles from "./Medien.module.css";

/** voll: das Uploadfeld einer Seite. mini: ein Anlege-Formular.
    zeile: die Kachel am linken Rand einer Listenzeile. */
export type Vorschaugroesse = "voll" | "mini" | "zeile";

/**
 * Die Vorschau eines Fotos oder Videos -- lokal gerade gewaehlt (per
 * Objekt-URL) oder schon gespeichert (per signierter URL), derselbe
 * Baustein fuer beides. Ohne URL ein gestrichelter Platzhalter statt gar
 * nichts (Designsystem 5: ein Zustand, kein Loch).
 *
 * `controls` ist seit der Zeilen-Groesse ein Prop und nicht mehr gesetzt:
 * ein 64 px breites Video traegt keine Bedienleiste, die sich noch treffen
 * liesse -- dort ist die Vorschau ein Standbild (das erste Bild, das der
 * Browser mit preload="metadata" ohnehin holt), und abgespielt wird an der
 * Stelle, die dafuer Platz hat.
 */
export function MedienVorschau({
  url,
  art,
  leerText,
  alt = "",
  groesse = "voll",
}: {
  url: string | null;
  art: "bild" | "video";
  leerText: string;
  /** Nur fuer ein Foto von Bedeutung -- ein Video traegt Bedienelemente
      (controls) und braucht keinen Alternativtext. Leer = dekorativ. */
  alt?: string | undefined;
  groesse?: Vorschaugroesse;
}) {
  const klasse =
    groesse === "voll"
      ? styles.vorschau
      : groesse === "mini"
        ? styles.vorschauMini
        : styles.vorschauZeile;
  const leerKlasse =
    groesse === "voll"
      ? styles.vorschauLeer
      : groesse === "mini"
        ? styles.vorschauMiniLeer
        : styles.vorschauZeileLeer;

  if (!url) {
    return <div className={leerKlasse}>{leerText}</div>;
  }
  if (art === "video") {
    return (
      <video
        className={klasse}
        src={url}
        muted
        playsInline
        preload="metadata"
        controls={groesse !== "zeile"}
      />
    );
  }
  return (
    // eslint-disable-next-line @next/next/no-img-element
    <img className={klasse} src={url} alt={alt} />
  );
}
