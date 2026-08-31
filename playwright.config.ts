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
    command: "pnpm --filter @fitretro/web dev",
    url: "http://127.0.0.1:3000",
    reuseExistingServer: true,
    timeout: 120_000,
  },
});
