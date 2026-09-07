"use client";

import { useSelectedLayoutSegment } from "next/navigation";
import { Reiter } from "../../../../bausteine/Reiter";

/**
 * Der Reiter-Baustein ist eine Server-Komponente, die "aktiv" als
 * Eigenschaft von aussen erwartet (Reiter.tsx) -- aber layout.tsx, wo die
 * Reiterleiste fuer alle vier Reiter steht, ist selbst eine
 * Server-Komponente ueber allen vieren und bekommt das aktive Kindsegment
 * von Next nicht mitgeteilt: Layouts haben keinen Zugriff auf die
 * Routensegmente unter sich (Next-Doku zu useSelectedLayoutSegment). Dieser
 * Baustein ist deshalb der einzige Client-Rand auf dieser Seite -- er
 * ermittelt das Segment und reicht fertige aktiv-Werte an die
 * Server-Komponente Reiter weiter.
 */
export function ModellReiter({
  studioId,
  modelId,
  einstellungenZusatz,
  uebungenZusatz,
  instanzenZusatz,
}: {
  studioId: string;
  modelId: string;
  einstellungenZusatz: string;
  uebungenZusatz: string;
  instanzenZusatz: string;
}) {
  const segment = useSelectedLayoutSegment();
  const basis = `/portal/${studioId}/geraete/${modelId}`;

  return (
    <Reiter
      name="Modell"
      eintraege={[
        { href: basis, label: "Stammdaten", aktiv: segment === null },
        {
          href: `${basis}/einstellungen`,
          label: "Einstellungen",
          zusatz: einstellungenZusatz,
          aktiv: segment === "einstellungen",
        },
        {
          href: `${basis}/uebungen`,
          label: "Übungen",
          zusatz: uebungenZusatz,
          aktiv: segment === "uebungen",
        },
        {
          href: `${basis}/instanzen`,
          label: "Einzelne Geräte",
          zusatz: instanzenZusatz,
          aktiv: segment === "instanzen",
        },
      ]}
    />
  );
}
