import { defineConfig } from "vitest/config";

// Eigene Config noetig: ohne diese Datei sucht Vitest im Verzeichnisbaum
// aufwaerts und findet das Wurzel-`vitest.config.ts` (Integrationstests,
// `include: tests/integration/**`), wodurch hier "No test files found"
// ausgegeben wird statt der Paket-eigenen Unit-Tests.
export default defineConfig({
  test: {
    include: ["src/**/*.test.ts"],
  },
});
