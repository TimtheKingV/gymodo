import { describe, expect, it } from "vitest";
import { bereinigeVtt, videoIdAusAusgabe, waehleVtt } from "./transkript";

const VTT = `WEBVTT
Kind: captions
Language: de

00:01:07.000 --> 00:01:09.000 align:start position:0%
 
Wir starten<00:01:07.500><c> mit</c><00:01:08.000><c> dem</c><00:01:08.500><c> Atmen</c>

00:01:09.000 --> 00:01:11.000 align:start position:0%
Wir starten mit dem Atmen
 
und<00:01:09.500><c> dann</c>

00:01:11.000 --> 00:01:13.000
und dann
[Musik]

01:01:05.000 --> 01:01:07.000
Zum Schluss
`;

describe("bereinigeVtt", () => {
  it("entfernt Tags, Rollzeilen-Duplikate und Kopfzeilen", () => {
    expect(bereinigeVtt(VTT)).toEqual([
      "1:07 Wir starten mit dem Atmen",
      "1:09 und dann",
      "1:11 [Musik]",
      "61:05 Zum Schluss",
    ]);
  });

  it("gibt bei leerem Text eine leere Liste", () => {
    expect(bereinigeVtt("WEBVTT\n\n")).toEqual([]);
  });
});

describe("videoIdAusAusgabe", () => {
  it("nimmt die letzte nicht leere Zeile", () => {
    expect(videoIdAusAusgabe("[info] irgendwas\ndQw4w9WgXcQ\n\n")).toBe("dQw4w9WgXcQ");
  });
  it("lehnt Unbrauchbares ab", () => {
    expect(videoIdAusAusgabe("")).toBeNull();
    expect(videoIdAusAusgabe("ERROR: nope")).toBeNull();
  });
});

describe("waehleVtt", () => {
  it("nimmt nur die Datei dieses Videos", () => {
    const dateien = ["alt123456AB.de.vtt", "dQw4w9WgXcQ.de.vtt", "transkript.txt"];
    expect(waehleVtt(dateien, "dQw4w9WgXcQ")).toBe("dQw4w9WgXcQ.de.vtt");
  });
  it("liefert undefined, wenn nur fremde Untertitel da sind", () => {
    expect(waehleVtt(["alt123456AB.de.vtt"], "dQw4w9WgXcQ")).toBeUndefined();
  });
});
