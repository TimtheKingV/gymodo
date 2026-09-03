import styles from "./bausteine.module.css";

/**
 * Eine Zeile aus Titel, Meta und Aktionen -- die Grundeinheit jeder Liste
 * im Portal (Geraete, Tags, Team, Einladungen).
 *
 * Rendert ein <li>, nicht ein <div>: `Zeilen` traegt das <ul> drumherum.
 * Eine Liste von Geraeten ist eine Liste, und ein Screenreader sagt dann
 * "Liste mit 4 Eintraegen" -- das ist die Auskunft, um die es geht.
 */
export function Zeile({
  titel,
  meta,
  aktionen,
}: {
  titel: React.ReactNode;
  meta?: React.ReactNode;
  aktionen?: React.ReactNode;
}) {
  return (
    <li className={styles.zeile}>
      <div className={styles.zeileHaupt}>
        <div className={styles.zeileTitel}>{titel}</div>
        {meta ? <div className={styles.zeileMeta}>{meta}</div> : null}
      </div>
      {aktionen ? <div className={styles.zeileAktionen}>{aktionen}</div> : null}
    </li>
  );
}

/**
 * Der Umschlag: ein <ul> um beliebig viele `Zeile`n.
 */
export function Zeilen({ children }: { children: React.ReactNode }) {
  return <ul className={styles.zeilen}>{children}</ul>;
}
