/**
 * Die Wortmarke aus assets/branding/gymtavo-logo.html als SVG mit
 * Glyphenumrissen -- keine Webschrift, kein externer Request. Helle
 * Buchstaben, weil beide Seiten, die sie tragen, auf --bg stehen.
 */
export function GymtavoWordmark() {
  return (
    <img
      src="/branding/gymtavo-wordmark.svg"
      alt="GYMTAVO"
      width={128}
      height={24}
      style={{ display: "block", width: 128, height: "auto", flexShrink: 1, minWidth: 0 }}
    />
  );
}
