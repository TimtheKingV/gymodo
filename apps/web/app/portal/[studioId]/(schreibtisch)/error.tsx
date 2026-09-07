"use client";

import { Zustand } from "../../bausteine/Zustand";

/**
 * Diese Grenze faengt nur, was in page.tsx (und darunter) dieses Segments
 * wirft -- nicht layout.tsx selbst: Next haengt die Grenze eines Segments
 * um das, was das Segment als "children" rendert, nicht um das Segment
 * selbst. Die Rail-Navigation aus layout.tsx bleibt deshalb stehen, und
 * dieser Zustand landet innerhalb von dessen <main> -- kein eigener
 * Container noetig.
 *
 * Die Fehlermeldung selbst (error.message) erscheint hier bewusst nicht --
 * sie kann eine Datenbankmeldung enthalten, und die gehoert nicht vor einen
 * Trainer.
 */
export default function Fehler({ reset }: { error: Error; reset: () => void }) {
  return (
    <Zustand
      art="fehler"
      titel="Diese Seite liess sich nicht laden."
      naechsterSchritt="Der Katalog ist davon nicht betroffen — über die Navigation links kommst du weiter."
      aktion={
        <button type="button" onClick={reset}>
          Noch einmal versuchen
        </button>
      }
    />
  );
}
