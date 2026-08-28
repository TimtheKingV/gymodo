import { NextResponse } from "next/server";

export const dynamic = "force-static";

/**
 * Apple laedt diese Datei unter /.well-known/apple-app-site-association.
 * Der Pfad wird in next.config.mjs auf diese Route umgeschrieben.
 * Bedingungen von Apple: HTTPS, kein Redirect, Content-Type application/json.
 */
export function GET(): NextResponse {
  const teamId = process.env.APPLE_TEAM_ID;
  const bundleId = process.env.APPLE_BUNDLE_ID;
  if (!teamId || !bundleId) {
    // Diese Route ist "force-static": ein fehlender Wert wuerde sonst als
    // "undefined.undefined" in eine beim Build eingefrorene Datei einfrieren
    // und Apple scheitert lautlos an der Domain-Verknuepfung, ohne dass
    // irgendwo ein Fehler auftaucht. Deshalb hart scheitern statt weiterlaufen.
    throw new Error(
      "APPLE_TEAM_ID und APPLE_BUNDLE_ID muessen gesetzt sein, um die AASA-Datei zu erzeugen.",
    );
  }
  const appId = `${teamId}.${bundleId}`;

  return NextResponse.json(
    {
      applinks: {
        details: [
          {
            appIDs: [appId],
            components: [{ "/": "/t/*", comment: "Geraete-Tags" }],
          },
        ],
      },
    },
    { headers: { "content-type": "application/json" } },
  );
}
