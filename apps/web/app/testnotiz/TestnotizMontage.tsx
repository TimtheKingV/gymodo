import { cookies } from "next/headers";
import dynamic from "next/dynamic";

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
  return <Oberflaeche angemeldet={await angemeldet()} />;
}

/**
 * Nur ja/nein, nie E-Mail oder Name: der Ordner traegt keine Personendaten
 * (Spec, Abschnitt Datenschutz).
 *
 * Und bewusst ohne Supabase-Client: der braeuchte SUPABASE_URL und
 * SUPABASE_ANON_KEY und wuerde ohne sie werfen -- ein Debug-Werkzeug darf
 * keine Seite mitnehmen, wenn eine Umgebung unvollstaendig konfiguriert ist
 * (gesehen in einer Vorschau, 2026-09-22). Der Keks des Anmeldediensts
 * beantwortet die Frage ohne Netz und ohne Konfiguration.
 */
async function angemeldet(): Promise<boolean> {
  try {
    const kekse = await cookies();
    return kekse.getAll().some((keks) => /^sb-.+-auth-token(\.\d+)?$/.test(keks.name));
  } catch {
    return false;
  }
}
