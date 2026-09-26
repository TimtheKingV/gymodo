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
  aktionenOben = false,
  bild,
  darunter,
}: {
  titel: React.ReactNode;
  meta?: React.ReactNode;
  aktionen?: React.ReactNode;
  /** Aktionen oben rechts statt mittig -- fuer den einzelnen Stift
      (Stift.tsx), der wie eine Ecke der Karte sitzen soll. */
  aktionenOben?: boolean;
  /** Die Kachel am linken Rand -- das Geraetefoto in der Modellliste.
      Optional, weil die meisten Listen des Portals (Tags, Leute, Termine)
      kein Bild haben und keins erfinden sollen. */
  bild?: React.ReactNode;
  /** Was unter der Zeile aufklappt, in voller Breite -- die Optionen
      hinter einem Stift (Testnotiz 25.09., #5). */
  darunter?: React.ReactNode;
}) {
  return (
    <li className={darunter ? styles.zeileMitDarunter : styles.zeile}>
      <div className={styles.zeileMitBild}>
        {bild}
        <div className={styles.zeileHaupt}>
          <div className={styles.zeileTitel}>{titel}</div>
          {meta ? <div className={styles.zeileMeta}>{meta}</div> : null}
        </div>
      </div>
      {aktionen ? (
        <div className={aktionenOben ? styles.zeileAktionenOben : styles.zeileAktionen}>
          {aktionen}
        </div>
      ) : null}
      {darunter ? <div className={styles.zeileDarunter}>{darunter}</div> : null}
    </li>
  );
}

/**
 * Der Umschlag: ein <ul> um beliebig viele `Zeile`n.
 */
export function Zeilen({ children }: { children: React.ReactNode }) {
  return <ul className={styles.zeilen}>{children}</ul>;
}
