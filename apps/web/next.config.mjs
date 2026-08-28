/** @type {import('next').NextConfig} */
const nextConfig = {
  // @fitretro/domain liefert TS-Quellen aus (main: "./src/index.ts") und
  // nutzt darin .js-Importe, die TypeScripts "moduleResolution: bundler"
  // auf .ts-Dateien mappt. Ohne transpilePackages transformiert Webpack
  // dieses Workspace-Paket nicht und findet "./tags.js" nicht.
  transpilePackages: ["@fitretro/domain"],
  webpack(config) {
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
