import { defineConfig } from "@playwright/test";
import "dotenv/config";

// Der Port ist ueberschreibbar, weil auf dieser Maschine mehrere
// Worktrees nebeneinander laufen: haelt eine Parallelsession bereits
// 3000, liefe der Test sonst gegen deren Code -- reuseExistingServer
// ist lokal true. Ohne E2E_PORT bleibt alles wie bisher.
//
// Der Port geht per "-p" direkt an next dev/next start, nicht per "--"
// hinter dem pnpm-Skriptnamen: pnpm reicht das "--" hier woertlich an
// next durch (next dev "--" "-p" "3001"), und next deutet das "--" als
// Ende der Flags -- "-p" landet dann als (nicht existierendes)
// Projektverzeichnis. Ohne "--" bekommt next "-p" als das, was es ist,
// verifiziert per netstat waehrend next dev lief.
const port = process.env.E2E_PORT ?? "3000";
const basis = `http://127.0.0.1:${port}`;

export default defineConfig({
  testDir: "./e2e",
  timeout: 120_000,
  // Der Dev-Server uebersetzt jede Route beim ersten Aufruf. Die
  // Standard-5-Sekunden reichen dafuer nicht -- der Test wuerde nicht einen
  // Fehler finden, sondern den Uebersetzungsvorgang.
  expect: { timeout: 20_000 },
  use: { baseURL: basis },
  webServer: {
    // In der CI gegen den Produktionsbau, lokal gegen den Dev-Server.
    //
    // Der Grund ist gemessen, nicht vermutet: der Dev-Server uebersetzt jede
    // Route beim ersten Aufruf, und bei kaltem .next-Verzeichnis treffen
    // mehrere Worker gleichzeitig auf jeweils neue Routen. Am 3. September
    // fielen dabei in drei Laeufen drei verschiedene Tests aus -- Anmeldung
    // im Timeout, ein Knopf, dessen Handler noch nicht hydriert war, eine
    // Seite, die nicht fertig lud. Mit warmem Cache liefen dieselben 26
    // Tests durch. Ein fertiger Bau kennt diesen Zustand nicht.
    //
    // Der Nebengewinn: die CI prueft damit das Artefakt, das ausgeliefert
    // wird, und nicht eine Fassung, die es so nie gibt.
    command: process.env.CI
      ? `pnpm --filter @fitretro/web start -p ${port}`
      : `pnpm --filter @fitretro/web dev -p ${port}`,
    url: basis,
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
});
