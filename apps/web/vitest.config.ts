import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    // Ohne eigene Config wuerde Vitest beim Hochlaufen im Verzeichnisbaum
    // bis zur Monorepo-Wurzel suchen und dort vitest.config.ts (Integrationstests,
    // include: "tests/integration/**") finden — das Include-Pattern passt
    // aber nicht auf die Unit-Tests hier. Deshalb eine eigene, unrestriktive Config.
    include: ["**/*.test.ts"],
    exclude: ["node_modules", ".next"],
  },
});
