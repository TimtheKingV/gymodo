import styles from "./Medien.module.css";

export type Bildgroesse = "kopf" | "zeile";

/**
 * Das Foto eines Geraetemodells, ueberall dort, wo von dem Modell die Rede
 * ist -- Modellkopf, Modellliste, Uebungszeile.
 *
 * Bis hierher zeigte das Portal Fotos an genau einer Stelle: im
 * Stammdaten-Formular, in dem man sie hochlaedt. Die Liste, die Reiter und
 * der Ueberblick waren Text, obwohl `ladeKatalog` die signierten URLs
 * ohnehin fuer jedes Modell mitliefert. Ein Bildarchiv, das aussieht wie
 * eine Tabelle.
 *
 * Getrennt von MedienVorschau, obwohl beide ein Bild in einen Rahmen
 * setzen: MedienVorschau zeigt, was gerade hochgeladen wird (auch Video,
 * auch als Objekt-URL im Browser), dieses hier zeigt, was ein Objekt IST.
 * Der Unterschied steht im Alternativtext -- "Foto von Latzug" gegen den
 * leeren, dekorativen alt einer Uploadvorschau.
 */
export function Modellbild({
  url,
  name,
  leerText,
  groesse,
}: {
  url: string | undefined;
  name: string;
  leerText: string;
  groesse: Bildgroesse;
}) {
  const klasse = groesse === "kopf" ? styles.bildKopf : styles.bildZeile;
  const leerKlasse = groesse === "kopf" ? styles.bildKopfLeer : styles.bildZeileLeer;

  if (!url) {
    return (
      <div className={leerKlasse} aria-hidden="true">
        {leerText}
      </div>
    );
  }
  return (
    // eslint-disable-next-line @next/next/no-img-element
    <img className={klasse} src={url} alt={`Foto von ${name}`} />
  );
}
