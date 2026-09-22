"use client";

import type { Routenknoten } from "@/lib/testnotiz/seitendatei";

/**
 * Die Routenkarte, die `next.config.mjs` zur Bauzeit gelesen und per
 * DefinePlugin hier eingesetzt hat.
 *
 * Frueher loeste der Dev-Server den Pfad beim Sichern auf; ohne Server muss
 * der Browser es koennen, und dafuer braucht er den Verzeichnisbaum als
 * Wert. Der Waechter faengt die Faelle ab, in denen die Kennung nicht
 * ersetzt wurde -- im Einheitentest etwa gibt es kein Webpack.
 */
declare const __TESTNOTIZ_ROUTEN__: Routenknoten | null;

export function routenkarte(): Routenknoten | null {
  return typeof __TESTNOTIZ_ROUTEN__ === "undefined" ? null : __TESTNOTIZ_ROUTEN__;
}
