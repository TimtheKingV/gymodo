import { describe, expect, it } from "vitest";
import { aufwaermenMinuten, cardioMinuten, pauseSekunden, uebungMinuten } from "./trainingsplan-zeit.js";

describe("trainingsplan-zeit", () => {
  it("rechnet Uebungsdauer", () => {
    expect(uebungMinuten("mehrgelenk", 3)).toBe(10.25);
    expect(uebungMinuten("isolation", 3)).toBe(6.75);
    expect(uebungMinuten("mehrgelenk", 2)).toBe(7);
    expect(uebungMinuten("isolation", 2)).toBe(4.5);
  });
  it("Cardio nach Zeitbudget", () => {
    expect(cardioMinuten(30)).toBe(0);
    expect(cardioMinuten(45)).toBe(10);
    expect(cardioMinuten(60)).toBe(20);
    expect(cardioMinuten(75)).toBe(20);
    expect(cardioMinuten(90)).toBe(20);
  });
  it("Aufwaermen und Pausen", () => {
    expect(aufwaermenMinuten(30)).toBe(0);
    expect(aufwaermenMinuten(45)).toBe(5);
    expect(pauseSekunden("mehrgelenk")).toBe(150);
    expect(pauseSekunden("isolation")).toBe(90);
  });
});
