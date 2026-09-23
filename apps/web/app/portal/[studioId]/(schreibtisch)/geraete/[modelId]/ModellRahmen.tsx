"use client";

import Link from "next/link";
import { useSearchParams, useSelectedLayoutSegment } from "next/navigation";
import { Schrittleiste } from "../../../../bausteine/Schrittleiste";
import { ASSISTENT_PARAM, ASSISTENT_SCHRITTE, assistentSchritt } from "../assistent";
import { ModellReiter } from "./ModellReiter";
import styles from "../../../../portal.module.css";

/**
 * Was um den Inhalt eines Modell-Reiters steht -- im Normalfall
 * Reiterleiste und "Noch zu tun", im Ablauf "Gerät hinzufügen" (`?neu=1`,
 * Testnotiz 23.09., #7) stattdessen Schrittleiste oben und Zurück/Weiter
 * unten. Die Reiterseiten selbst merken davon nichts.
 *
 * Ein Client-Baustein, weil layout.tsx weder das aktive Kindsegment noch
 * die Suchparameter sieht (Layouts bekommen keine searchParams). Das Band
 * "Noch zu tun" rendert weiter der Server und kommt als fertiges Element
 * herein.
 */
export function ModellRahmen({
  studioId,
  modelId,
  einstellungenZusatz,
  uebungenZusatz,
  instanzenZusatz,
  nochZuTun,
  children,
}: {
  studioId: string;
  modelId: string;
  einstellungenZusatz: string;
  uebungenZusatz: string;
  instanzenZusatz: string;
  nochZuTun: React.ReactNode;
  children: React.ReactNode;
}) {
  const segment = useSelectedLayoutSegment();
  const imAblauf = useSearchParams().get(ASSISTENT_PARAM) === "1";
  const schritt = imAblauf ? assistentSchritt(studioId, modelId, segment) : null;

  if (!schritt) {
    return (
      <>
        <ModellReiter
          studioId={studioId}
          modelId={modelId}
          einstellungenZusatz={einstellungenZusatz}
          uebungenZusatz={uebungenZusatz}
          instanzenZusatz={instanzenZusatz}
        />
        {nochZuTun}
        {children}
      </>
    );
  }

  return (
    <>
      <div className={styles.ablaufLeiste}>
        <Schrittleiste nummer={schritt.nummer} titel={schritt.titel} von={ASSISTENT_SCHRITTE} />
      </div>
      {children}
      {/* Genau ein Akzent: das Weiterkommen. Zurück ist sekundaer und
          fehlt im ersten Schritt -- davor liegt nur das Anlegen. */}
      <nav className={styles.ablaufFuss} aria-label="Ablauf">
        {schritt.zurueck ? (
          <Link href={schritt.zurueck} className={styles.secondary}>
            Zurück
          </Link>
        ) : (
          <span />
        )}
        <Link href={schritt.weiter.href} className={styles.primary}>
          {schritt.weiter.label}
        </Link>
      </nav>
    </>
  );
}
