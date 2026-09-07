import Link from "next/link";
import styles from "./bausteine.module.css";
import portalStyles from "../portal.module.css";

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
 *
 * `rueckweg` ist optional: die sechs Bildschirme des Einrichten-Gangs
 * zeigen vor dem Titel einen Rueckweg, den es am Schreibtisch nirgends
 * gibt. Werte wie .rueckweg in portal.module.css.
 */
export function Seite({
  titel,
  vorspann,
  rueckweg,
  children,
}: {
  titel: string;
  vorspann?: React.ReactNode;
  rueckweg?: { href: string; label: string };
  children: React.ReactNode;
}) {
  return (
    <>
      {rueckweg ? (
        <Link href={rueckweg.href} className={portalStyles.rueckweg}>
          ← {rueckweg.label}
        </Link>
      ) : null}
      <h1 className={styles.titel}>{titel}</h1>
      {vorspann ? <p className={styles.vorspann}>{vorspann}</p> : null}
      {children}
    </>
  );
}
