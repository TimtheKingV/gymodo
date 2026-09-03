import { Zustand } from "../../bausteine/Zustand";

/**
 * Faengt notFound() aus page.tsx (und darunter) dieses Segments -- zum
 * Beispiel modelle/[modelId]/page.tsx, wenn die Id zu keinem Modell mehr
 * gehoert. Landet wie error.tsx innerhalb von layout.tsx's <main>, die
 * Rail-Navigation bleibt stehen (siehe error.tsx).
 *
 * Faengt NICHT das notFound() aus ladeKatalog in layout.tsx selbst -- dafuer
 * ist apps/web/app/not-found.tsx da.
 */
export default function NichtGefunden() {
  return (
    <Zustand
      art="leer"
      titel="Diese Seite gibt es nicht."
      naechsterSchritt="Vielleicht wurde das Gerät stillgelegt oder das Studio gewechselt."
    />
  );
}
