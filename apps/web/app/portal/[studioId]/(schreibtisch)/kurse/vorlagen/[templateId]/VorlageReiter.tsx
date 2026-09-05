"use client";

import { useSelectedLayoutSegment } from "next/navigation";
import { Reiter } from "../../../../../bausteine/Reiter";

/**
 * Der Reiter-Baustein ist eine Server-Komponente, die "aktiv" als
 * Eigenschaft von aussen erwartet (Reiter.tsx) -- aber layout.tsx, wo die
 * Leiste fuer beide Reiter steht, ist selbst eine Server-Komponente ueber
 * beiden und bekommt das aktive Kindsegment von Next nicht mitgeteilt.
 * Dieser Baustein ist deshalb der einzige Client-Rand auf dieser Seite,
 * genau wie ModellReiter.tsx unter geraete/[modelId] -- er ermittelt das
 * Segment und reicht fertige aktiv-Werte weiter.
 *
 * aria-label "Kursvorlage": die Seite traegt zwei Navigationen (Rail und
 * Reiter), und "Navigation" zweimal ist keine Auskunft.
 */
export function VorlageReiter({
  studioId,
  templateId,
  termine,
}: {
  studioId: string;
  templateId: string;
  termine: number;
}) {
  const segment = useSelectedLayoutSegment();
  const basis = `/portal/${studioId}/kurse/vorlagen/${templateId}`;

  return (
    <Reiter
      name="Kursvorlage"
      eintraege={[
        { href: basis, label: "Stammdaten", aktiv: segment === null },
        {
          href: `${basis}/termine`,
          label: `Termine (${termine})`,
          zusatz: "in den nächsten 4 Wochen",
          aktiv: segment === "termine",
        },
      ]}
    />
  );
}
