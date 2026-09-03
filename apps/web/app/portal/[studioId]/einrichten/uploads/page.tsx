"use client";

import Link from "next/link";
import { use } from "react";
import { useUploads, type Auftrag } from "../Uploads";
import styles from "../halle.module.css";

const STAND_TEXT: Record<Auftrag["stand"], string> = {
  wartet: "wartet",
  laeuft: "wird übertragen",
  prueft: "wird geprüft",
  fertig: "oben",
  fehler: "unterbrochen",
};

export default function UploadsPage({
  params,
}: {
  params: Promise<{ studioId: string }>;
}) {
  const { studioId } = use(params);
  const { auftraege, offen } = useUploads();

  return (
    <>
      <div>
        <Link href={`/portal/${studioId}/einrichten`} className={styles.zurueck}>
          ← Einrichten
        </Link>
        <h1 className={styles.titel}>Uploads</h1>
        <p className={styles.unterzeile}>
          Läuft weiter, während du weitergehst.
        </p>
      </div>

      {auftraege.length === 0 ? (
        <p className={styles.notiz}>Nichts in der Warteschlange.</p>
      ) : (
        <section className={styles.abschnitt}>
          <div className={styles.abschnittKopf}>
            <h2 className={styles.label}>Warteschlange</h2>
            <span className={styles.zeileMeta}>{offen} offen</span>
          </div>
          {auftraege.map((auftrag) => (
            <div key={auftrag.id} className={styles.zeile}>
              <div style={{ minWidth: 0, width: "100%" }}>
                <div className={styles.zeileHaupt}>{auftrag.titel}</div>
                <div className={styles.zeileMeta}>
                  {(auftrag.datei.size / 1024 / 1024).toFixed(1)} MB ·{" "}
                  {STAND_TEXT[auftrag.stand]}
                </div>
                {auftrag.stand === "laeuft" || auftrag.stand === "wartet" ? (
                  <div
                    className={styles.balkenBahn}
                    role="progressbar"
                    aria-valuemin={0}
                    aria-valuemax={100}
                    aria-valuenow={Math.round(auftrag.anteil * 100)}
                    aria-label={`Fortschritt ${auftrag.titel}`}
                    style={{ marginTop: 8 }}
                  >
                    <div
                      className={styles.balken}
                      style={{ width: `${Math.round(auftrag.anteil * 100)}%` }}
                    />
                  </div>
                ) : null}
                {auftrag.fehler ? (
                  <p className={styles.fehler} role="alert">
                    {auftrag.fehler}
                  </p>
                ) : null}
                {auftrag.stand === "wartet" ? (
                  <span className={styles.notiz}>
                    Beginnt, sobald das vorige durch ist.
                  </span>
                ) : null}
              </div>
            </div>
          ))}
        </section>
      )}

      <div className={styles.karteWarnung}>
        <div className={styles.karteTitel}>Lass diesen Bildschirm offen</div>
        <p className={styles.notiz}>
          Safari hält Uploads an, sobald du zu einer anderen App wechselst. Sie
          gehen nicht verloren — sie warten, bis du zurückkommst. Ein Neuladen
          der Seite leert die Warteschlange allerdings: dann wählst du die
          Dateien noch einmal, und der Upload setzt fort, wo er stand.
        </p>
      </div>

      <Link href={`/portal/${studioId}/einrichten`} className={styles.neben}>
        Weiter einrichten
      </Link>
    </>
  );
}
