import dynamic from "next/dynamic";
import { createServerSupabaseClient } from "@/lib/supabase/server";

/**
 * Der eine Ort, an dem das Modul in die Seite kommt (`app/portal/layout.tsx`).
 *
 * Wie auf iOS jede Datei unter `#if DEBUG` steht, haengt hier alles an
 * Werten, die der Buendler beim Uebersetzen einsetzt: im Dev-Server und in
 * einer Vercel-Vorschau ist das Modul dabei, in der Produktionsfassung faellt
 * der ganze Zweig weg -- `next/dynamic` laedt seinen Teil erst, wenn er
 * wirklich gerendert wird, und der Zweig mit dem Import steht hinter einer
 * Bedingung, die schon beim Uebersetzen feststeht.
 *
 * `NEXT_PUBLIC_TESTNOTIZ=aus` schaltet es ueberall ab; unter Fernsteuerung
 * (Playwright) rendert die Oberflaeche selbst nichts.
 */

/**
 * `__TESTNOTIZ_AN__` setzt `next.config.mjs` beim Uebersetzen ein (dort steht
 * auch, warum nicht `process.env` an dieser Stelle). Die Bedingung muss
 * woertlich hier stehen: nur dann verwirft Webpack den toten Zweig samt
 * Import. Der `typeof`-Waechter faengt den Fall ab, dass jemand ohne diese
 * Konfiguration baut.
 */
declare const __TESTNOTIZ_AN__: boolean;

const Oberflaeche =
  typeof __TESTNOTIZ_AN__ !== "undefined" && __TESTNOTIZ_AN__
    ? dynamic(() => import("./TestnotizOberflaeche").then((modul) => modul.TestnotizOberflaeche))
    : null;

export async function TestnotizMontage() {
  if (!Oberflaeche) return null;

  // Nur ja/nein, nie E-Mail oder Name: der Ordner traegt keine Personendaten
  // (Spec, Abschnitt Datenschutz).
  const client = await createServerSupabaseClient();
  const {
    data: { user },
  } = await client.auth.getUser();

  return <Oberflaeche angemeldet={user !== null} />;
}
