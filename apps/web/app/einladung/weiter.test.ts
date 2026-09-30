import { describe, expect, it } from "vitest";
import { einladungsPfad, sichererWeiter } from "./weiter";

const token = "ab".repeat(32);

describe("sichererWeiter", () => {
  it("laesst den Weg zurueck zur Einladung durch", () => {
    expect(sichererWeiter(`/einladung/${token}`)).toBe(`/einladung/${token}`);
  });

  it("schickt alles andere auf die Startseite -- kein offener Umleiter", () => {
    expect(sichererWeiter(null)).toBe("/");
    expect(sichererWeiter("")).toBe("/");
    expect(sichererWeiter("https://evil.example")).toBe("/");
    expect(sichererWeiter("//evil.example/einladung/x")).toBe("/");
    expect(sichererWeiter(`/einladung/${token}/../../portal`)).toBe("/");
    expect(sichererWeiter("/portal")).toBe("/");
  });
});

describe("einladungsPfad", () => {
  it("baut den Pfad aus dem Token", () => {
    expect(einladungsPfad(token)).toBe(`/einladung/${token}`);
  });
});
