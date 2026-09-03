import { defineConfig } from "@playwright/test";
import "dotenv/config";

export default defineConfig({
  testDir: "./e2e",
  timeout: 120_000,
  // Der Dev-Server uebersetzt jede Route beim ersten Aufruf. Die
  // Standard-5-Sekunden reichen dafuer nicht -- der Test wuerde nicht einen
  // Fehler finden, sondern den Uebersetzungsvorgang.
  expect: { timeout: 20_000 },
  use: { baseURL: "http://127.0.0.1:3000" },
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
      ? "pnpm --filter @fitretro/web start"
      : "pnpm --filter @fitretro/web dev",
    url: "http://127.0.0.1:3000",
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
});
