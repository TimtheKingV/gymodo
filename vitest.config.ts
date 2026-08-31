import { fileURLToPath } from "node:url";
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["tests/integration/**/*.test.ts"],
    testTimeout: 30_000,
    hookTimeout: 30_000,
    fileParallelism: false,
  },
  resolve: {
    // Die API-Route-Handler importieren ueber den Next-Alias "@/". Damit sie
    // hier -- gegen echtes Postgres und echte RLS -- getestet werden koennen,
    // muss Vitest denselben Alias kennen.
    alias: {
      "@": fileURLToPath(new URL("./apps/web", import.meta.url)),
    },
  },
});
