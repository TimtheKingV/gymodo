import "./globals.css";

export const metadata = {
  title: "gymodo",
};

// Feste Breite, kein Zoom (Testnotiz 22.09., #2). maximumScale 1 verhindert
// zusaetzlich das automatische Hineinzoomen beim Fokus eines Felds;
// Zwei-Finger-Zoom sperrt touch-action in globals.css, weil iOS
// userScalable=false ignoriert.
export const viewport = {
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
  userScalable: false,
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="de">
      <body>{children}</body>
    </html>
  );
}
