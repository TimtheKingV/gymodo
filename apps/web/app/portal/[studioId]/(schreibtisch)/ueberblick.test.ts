import { describe, expect, it } from "vitest";
import { geraeteName } from "./ueberblick";

const katalog = {
  models: [
    {
      name: "Beinpresse",
      machines: [
        { id: "m-1", label: "3" },
        { id: "m-2", label: "4" },
      ],
    },
    { name: "Latzug", machines: [{ id: "m-3", label: "Links" }] },
  ],
};

describe("geraeteName", () => {
  it("nennt Geraetetyp und Nummer, nicht nur die Nummer (Testnotiz 25.09., #2)", () => {
    expect(geraeteName(katalog, "m-2", "4")).toBe("Beinpresse 4");
    expect(geraeteName(katalog, "m-3", "Links")).toBe("Latzug Links");
  });

  it("faellt auf die Nummer zurueck, wenn das Geraet nicht im Katalog steht", () => {
    expect(geraeteName(katalog, "unbekannt", "7")).toBe("7");
  });
});
