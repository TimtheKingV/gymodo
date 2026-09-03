import styles from "./bausteine.module.css";

/**
 * Titel, Vorspann, Rumpf.
 *
 * Rendert bewusst KEIN <main>. Bis Aufgabe 4 rendert das Layout
 * <main>{children}</main> und vier Seiten darin noch ein eigenes --
 * (schreibtisch)/page.tsx, leute, einstellungen und einstellungen/konto
 * tragen damit zwei verschachtelte Hauptbereiche. Vier weitere haben an
 * derselben Stelle ein <div>, das denselben Innenabstand mitbringt und
 * ihn nach Aufgabe 4 verdoppeln wuerde.
 *
 * Die Landmarke gehoert dem Layout, weil es genau eine gibt und es genau
 * ein Layout gibt. Ein Baustein, der sie nicht mitbringt, macht beide
 * Fehler unmoeglich statt sie zu reparieren.
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
