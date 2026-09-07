import styles from "./bausteine.module.css";

/**
 * Titel, Vorspann, Rumpf.
 *
 * Rendert bewusst KEIN <main>. Die Landmarke gehoert dem Layout, weil es
 * genau eine gibt und es genau ein Layout gibt. Ein Baustein, der sie nicht
 * mitbringt, macht beide Fehler unmoeglich statt sie zu reparieren. Vor
 * Aufgabe 4 hatten vier Seiten darin ein eigenes <main>, das zwei
 * verschachtelte Hauptbereiche erzeugte; heute traegt allein das Layout die
 * Landmarke, und alle zwölf styles.content-Hüllen unter (schreibtisch)/
 * sind weg.
 */
export function Seite({
  titel,
  vorspann,
  children,
}: {
  titel: string;
  vorspann?: React.ReactNode;
  children: React.ReactNode;
}) {
  return (
    <>
      <h1 className={styles.titel}>{titel}</h1>
      {vorspann ? <p className={styles.vorspann}>{vorspann}</p> : null}
      {children}
    </>
  );
}
