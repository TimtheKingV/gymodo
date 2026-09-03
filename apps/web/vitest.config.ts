import react from "@vitejs/plugin-react";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [react()],
  test: {
    // Ohne eigene Config wuerde Vitest beim Hochlaufen im Verzeichnisbaum
    // bis zur Monorepo-Wurzel suchen und dort vitest.config.ts (Integrationstests,
    // include: "tests/integration/**") finden — das Include-Pattern passt
    // aber nicht auf die Unit-Tests hier. Deshalb eine eigene, unrestriktive Config.
    //
    // .tsx gehoert seit den Bausteinen dazu. Ohne die Erweiterung liefe
    // Zustand.test.tsx nie, und der Lauf waere trotzdem gruen.
    include: ["**/*.test.ts", "**/*.test.tsx"],
    exclude: ["node_modules", ".next"],
  },
});
