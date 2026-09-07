import { Zustand } from "./portal/bausteine/Zustand";

/**
 * Faengt zwei Faelle: eine URL, die zu keiner Route passt, UND das
 * notFound() aus ladeKatalog in (schreibtisch)/layout.tsx -- Letzteres,
 * weil eine Grenze eines Segments nur dessen "children" umschliesst, nicht
 * das Segment selbst (siehe (schreibtisch)/not-found.tsx). Ohne diese Datei
 * landete dieser Fall auf Nexts weisser Standardseite, mitten in einem
 * Portal, das sonst durchgehend var(--bg) ist.
 *
 * Kein Rail, keine Studio-Navigation: an dieser Stelle ist unklar, ob es
 * ueberhaupt ein gueltiges Studio gibt. Das Padding ist eine eigene, nicht
 * aus einer Spec-Quelle belegte Entscheidung -- ohne sie stuende die Karte
 * an der Fensterkante.
 */
export default function NichtGefunden() {
  return (
    <div style={{ padding: "var(--s32) var(--s40) var(--s48)", maxWidth: "960px" }}>
      <Zustand
        art="leer"
        titel="Diese Seite gibt es nicht."
        naechsterSchritt="Vielleicht wurde das Gerät stillgelegt oder das Studio gewechselt."
      />
    </div>
  );
}
