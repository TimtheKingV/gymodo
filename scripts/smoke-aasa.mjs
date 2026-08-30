#!/usr/bin/env node
const domain = process.argv[2];
if (!domain) {
  console.error("Aufruf: node scripts/smoke-aasa.mjs <domain>");
  process.exit(2);
}

const url = `https://${domain}/.well-known/apple-app-site-association`;
const response = await fetch(url, { redirect: "manual" });

const failures = [];
if (response.status !== 200) {
  failures.push(`Status ${response.status}, erwartet 200`);
}
if (response.headers.get("location")) {
  failures.push("Redirect vorhanden — Apple folgt keinem Redirect");
}
const contentType = response.headers.get("content-type") ?? "";
if (!contentType.includes("application/json")) {
  failures.push(`Content-Type "${contentType}", erwartet application/json`);
}

let body;
try {
  body = await response.json();
} catch {
  failures.push("Antwort ist kein gueltiges JSON");
}

const component = body?.applinks?.details?.[0]?.components?.[0]?.["/"];
if (component !== "/t/*") {
  failures.push(`Pfadkomponente "${component}", erwartet "/t/*"`);
}

const appId = body?.applinks?.details?.[0]?.appIDs?.[0];
if (!/^[A-Z0-9]{10}\..+/.test(appId ?? "")) {
  failures.push(`App-ID "${appId}" hat nicht das Format TEAMID.BUNDLEID`);
}

if (failures.length > 0) {
  console.error(`AASA-Smoke-Test fehlgeschlagen fuer ${url}:`);
  for (const failure of failures) console.error(`  - ${failure}`);
  process.exit(1);
}

console.log(`AASA-Smoke-Test bestanden fuer ${url}`);
