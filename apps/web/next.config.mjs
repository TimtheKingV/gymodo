import path from "node:path";
import { fileURLToPath } from "node:url";
import { karteLesen } from "./lib/testnotiz/routenkarte.mjs";

/**
 * Das Testnotiz-Modul laeuft im Dev-Server und in einer Vercel-Vorschau,
 * nie in der Produktionsfassung -- dieselbe Bedingung wie in
 * `app/testnotiz/TestnotizMontage.tsx`.
 */
const TESTNOTIZ_AN =
  (process.env.NODE_ENV !== "production" || process.env.NEXT_PUBLIC_VERCEL_ENV === "preview") &&
  process.env.NEXT_PUBLIC_TESTNOTIZ !== "aus";

/**
 * Welche Quelldatei hinter einer URL steht, weiss nur der Verzeichnisbaum.
 * Frueher las ihn der Dev-Server beim Sichern; seit die Sitzung ohne Server
 * auskommt, muss der Browser es koennen -- also wandert die Karte hier, zur
 * Bauzeit, als Wert ins Buendel. In der Produktionsfassung bleibt sie leer,
 * damit keine Pfadliste im ausgelieferten Code steht.
 *
 * Gelesen wird beim Start: eine Route, die waehrend einer laufenden
 * `next dev`-Sitzung neu entsteht, steht erst nach einem Neustart in der
 * Karte.
 */
const routenkarte = TESTNOTIZ_AN
  ? karteLesen(path.join(path.dirname(fileURLToPath(import.meta.url)), "app"), "apps/web/app")
  : null;

/** @type {import('next').NextConfig} */
const nextConfig = {
  // @fitretro/domain liefert TS-Quellen aus (main: "./src/index.ts") und
  // nutzt darin .js-Importe, die TypeScripts "moduleResolution: bundler"
  // auf .ts-Dateien mappt. Ohne transpilePackages transformiert Webpack
  // dieses Workspace-Paket nicht und findet "./tags.js" nicht.
  transpilePackages: ["@fitretro/domain"],
  experimental: {
    serverActions: {
      // Next schneidet den Rumpf einer Server Action ohne diesen Eintrag bei
      // 1 MB ab -- mit 413 und ohne dass die Fachschicht die Bytes je sieht.
      // MAX_PHOTO_BYTES steht auf 10 MiB, ein Foto aus einer Handykamera
      // liegt bei 2 bis 5 MB. Das Geraetefoto laeuft bewusst durch den
      // Server (nur dort lassen sich die Aufnahmedaten entfernen), also muss
      // die Transportgrenze zur fachlichen passen; die zwei MiB Aufschlag
      // decken den Multipart-Rahmen und die uebrigen Formularfelder.
      //
      // Das Einweisungsvideo braucht das nicht: es geht per TUS direkt gegen
      // den Storage-Dienst, an den Server Actions vorbei.
      bodySizeLimit: "12mb",
    },
  },
  // Playwright faehrt die Seite ueber 127.0.0.1 an, der Dev-Server bindet
  // localhost. Ohne diesen Eintrag warnt Next bei jedem Lauf vor einer
  // Cross-Origin-Anfrage -- und macht daraus in einer kuenftigen
  // Hauptversion einen Fehler.
  allowedDevOrigins: ["127.0.0.1"],
  webpack(config, { webpack }) {
    // Die Karte als Wert, nicht als Datei: DefinePlugin ersetzt die Kennung
    // beim Uebersetzen, der Browser bekommt also fertige Daten und keinen
    // Dateisystemzugriff (den es dort nicht gibt).
    config.plugins.push(
      new webpack.DefinePlugin({
        // Der Schalter gehoert hierher und nicht in den Quelltext: Next
        // ersetzt `process.env.NEXT_PUBLIC_…` nur fuer Variablen, die beim
        // Bauen gesetzt SIND. Eine nicht gesetzte bleibt als Ausdruck stehen,
        // und dann kann Webpack den toten Zweig nicht verwerfen -- das ganze
        // Modul landete so im Produktionsbuendel (gemessen, 2026-09-22).
        // Als eigener Wert steht die Antwort beim Uebersetzen fest.
        __TESTNOTIZ_AN__: JSON.stringify(TESTNOTIZ_AN),
        __TESTNOTIZ_ROUTEN__: JSON.stringify(routenkarte),
      }),
    );

    // transpilePackages allein reicht nicht: Webpack sucht bei einem
    // expliziten ".js"-Specifier nur die Datei "tags.js" woertlich und
    // versucht keine Alternativendung. extensionAlias bildet das TS-Pattern
    // "moduleResolution: bundler" (.js-Import -> .ts-Datei) fuer Webpack nach.
    config.resolve.extensionAlias = {
      ...config.resolve.extensionAlias,
      ".js": [".ts", ".tsx", ".js"],
    };
    return config;
  },
  async rewrites() {
    return [
      {
        source: "/.well-known/apple-app-site-association",
        destination: "/api/aasa",
      },
    ];
  },
};

export default nextConfig;
