import styles from "./Medien.module.css";

/**
 * Die Vorschau eines Fotos oder Videos -- lokal gerade gewaehlt (per
 * Objekt-URL) oder schon gespeichert (per signierter URL), derselbe
 * Baustein fuer beides. Ohne URL ein gestrichelter Platzhalter statt gar
 * nichts (Designsystem 5: ein Zustand, kein Loch).
 */
export function MedienVorschau({
  url,
  art,
  leerText,
  alt = "",
  mini = false,
}: {
  url: string | null;
  art: "bild" | "video";
  leerText: string;
  /** Nur fuer ein Foto von Bedeutung -- ein Video traegt Bedienelemente
      (controls) und braucht keinen Alternativtext. Leer = dekorativ. */
  alt?: string | undefined;
  mini?: boolean;
}) {
  if (!url) {
    return <div className={mini ? styles.vorschauMiniLeer : styles.vorschauLeer}>{leerText}</div>;
  }
  if (art === "video") {
    return (
      <video
        className={mini ? styles.vorschauMini : styles.vorschau}
        src={url}
        muted
        playsInline
        controls
      />
    );
  }
  return (
    // eslint-disable-next-line @next/next/no-img-element
    <img className={mini ? styles.vorschauMini : styles.vorschau} src={url} alt={alt} />
  );
}
