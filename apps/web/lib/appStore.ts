// Die App ist noch nicht im App Store (Stand 3. Oktober). Bis dahin zeigt
// der Link wie /t/[token] auf die Store-Startseite -- ein Ziel, das es gibt,
// statt eines toten Links.
export const APP_STORE_URL =
  process.env.NEXT_PUBLIC_APP_STORE_URL || "https://apps.apple.com/";
