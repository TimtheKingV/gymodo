import { NextResponse } from "next/server";

export const dynamic = "force-static";

/**
 * Apple laedt diese Datei unter /.well-known/apple-app-site-association.
 * Der Pfad wird in next.config.mjs auf diese Route umgeschrieben.
 * Bedingungen von Apple: HTTPS, kein Redirect, Content-Type application/json.
 */
export function GET(): NextResponse {
  const appId = `${process.env.APPLE_TEAM_ID}.${process.env.APPLE_BUNDLE_ID}`;

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
