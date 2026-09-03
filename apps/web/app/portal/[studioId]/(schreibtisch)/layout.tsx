import { Rail } from "../Rail";
import { erreichbarkeit, ladeKatalog } from "../catalog";
import styles from "../../portal.module.css";

export default async function StudioLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: Promise<{ studioId: string }>;
}) {
  const { studioId } = await params;
  const katalog = await ladeKatalog(studioId);

  return (
    <div className={styles.shell}>
      <Rail
        studioId={studioId}
        studioName={katalog.studioName}
        models={katalog.models.map((modell) => ({
          id: modell.id,
          name: modell.name,
          ...erreichbarkeit(modell),
        }))}
        offeneTags={katalog.tags.filter((tag) => tag.status === "unassigned").length}
      />
      <main>{children}</main>
    </div>
  );
}
