import { nichtImKatalog } from "../../katalogStudio";

/** Gibt es im Gymtavo-Studio nicht (katalogStudio.ts). */
export default async function NurStudioLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: Promise<{ studioId: string }>;
}) {
  await nichtImKatalog((await params).studioId);
  return children;
}
