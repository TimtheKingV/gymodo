import { describe, expect, it } from "vitest";
import { isValidTagToken, parseTagScan } from "./tag-scan.js";

const TOKEN = "AbCdEfGhIjKlMnOpQrStUv";

describe("parseTagScan", () => {
  it("nimmt den blanken Token, wie ihn der Rueckfallweg eintippt", () => {
    expect(parseTagScan(TOKEN)).toBe(TOKEN);
  });

  it("schneidet Leerraum weg -- ein Tastaturvorschlag haengt gern eines an", () => {
    expect(parseTagScan(`  ${TOKEN} `)).toBe(TOKEN);
  });

  it("liest den Token aus der Adresse, die auf dem Tag steht", () => {
    expect(parseTagScan(`https://gymodo-web.vercel.app/t/${TOKEN}`)).toBe(TOKEN);
  });

  it("liest ihn auch mit Schraegstrich, Abfrage und Anker dahinter", () => {
    expect(parseTagScan(`https://example.test/t/${TOKEN}/`)).toBe(TOKEN);
    expect(parseTagScan(`https://example.test/t/${TOKEN}?von=nfc`)).toBe(TOKEN);
    expect(parseTagScan(`https://example.test/t/${TOKEN}#oben`)).toBe(TOKEN);
  });

  it("weist einen fremden QR ab, statt etwas zu erfinden", () => {
    expect(parseTagScan("https://example.test/irgendwas")).toBeNull();
    expect(parseTagScan("WLAN:S=Kraftwerk;T=WPA;P=geheim;;")).toBeNull();
    expect(parseTagScan("")).toBeNull();
  });

  it("weist einen zu kurzen und einen zu langen Token ab", () => {
    expect(parseTagScan("AbCdEfGhIjKlMnOpQrStU")).toBeNull();
    expect(parseTagScan("AbCdEfGhIjKlMnOpQrStUvW")).toBeNull();
  });

  // Ein 23-Zeichen-Token in einer Adresse darf nicht stillschweigend auf 22
  // zurueckschneiden -- das zeigte auf einen fremden Tag.
  it("schneidet einen zu langen Token in der Adresse nicht zurecht", () => {
    expect(parseTagScan(`https://example.test/t/${TOKEN}W`)).toBeNull();
  });

  it("weist Zeichen ab, die base64url nicht kennt", () => {
    expect(parseTagScan("AbCdEfGhIjKlMnOpQrSt+/")).toBeNull();
  });

  // Der Locator steht im Klartext auf einem Aufkleber -- die Klein- und
  // Grossschreibung traegt Information und darf nicht eingeebnet werden.
  it("bleibt schreibungsempfindlich", () => {
    expect(parseTagScan(TOKEN.toLowerCase())).toBe(TOKEN.toLowerCase());
    expect(parseTagScan(TOKEN.toLowerCase())).not.toBe(TOKEN);
  });
});

describe("isValidTagToken", () => {
  it("gilt fuer genau 22 base64url-Zeichen", () => {
    expect(isValidTagToken(TOKEN)).toBe(true);
    expect(isValidTagToken("zu-kurz")).toBe(false);
  });
});
