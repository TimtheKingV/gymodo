import dynamic from "next/dynamic";
import { createServerSupabaseClient } from "@/lib/supabase/server";

/**
 * Der eine Ort, an dem das Modul in die Seite kommt (`app/portal/layout.tsx`).
 *
 * Wie auf iOS jede Datei unter `#if DEBUG` steht, haengt hier alles am
 * Entwicklungsbau: im Produktionsbau gibt diese Komponente `null` zurueck,
 * die Oberflaeche wird nie angefordert -- `next/dynamic` laedt ihren Teil
 * erst, wenn er wirklich gerendert wird -- und die Route, die den Ordner
 * schreibt, antwortet mit 404.
 *
 * Abgeschaltet wird es ausserdem durch `NEXT_PUBLIC_TESTNOTIZ=aus` (etwa fuer
 * eine Vorfuehrung) und, in der Oberflaeche selbst, unter Fernsteuerung
 * (Playwright).
 */

/**
 * Der Zweig mit dem Import steht hinter einer Bedingung, die der Buendler
 * schon beim Uebersetzen kennt (`process.env.NODE_ENV`). Im Produktionsbau
 * faellt er damit weg, bevor Webpack den Import ueberhaupt liest -- die
 * Oberflaeche steht dann in keinem Stueck des Buendels. Geprueft mit einer
 * Suche nach ihren Texten in `.next/static` und `.next/server`.
 */
const Oberflaeche =
  process.env.NODE_ENV === "production"
    ? null
    : dynamic(() => import("./TestnotizOberflaeche").then((modul) => modul.TestnotizOberflaeche));

export async function TestnotizMontage() {
  if (!Oberflaeche) return null;
  if (process.env.NEXT_PUBLIC_TESTNOTIZ === "aus") return null;

  // Nur ja/nein, nie E-Mail oder Name: der Ordner traegt keine Personendaten
  // (Spec, Abschnitt Datenschutz).
  const client = await createServerSupabaseClient();
  const {
    data: { user },
  } = await client.auth.getUser();

  return <Oberflaeche angemeldet={user !== null} />;
}
