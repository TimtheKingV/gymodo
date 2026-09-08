import Link from "next/link";
import { notFound } from "next/navigation";
import { ladeKatalog } from "../../../catalog";
import { ModellReiter } from "./ModellReiter";
import styles from "../../../../portal.module.css";

/** 80,0 statt 80 -- sonst liest sich ein Wechsel auf 82,5 wie ein Formatfehler. */
function kg(wert: number): string {
  return `${wert.toLocaleString("de-DE", { minimumFractionDigits: 1, maximumFractionDigits: 1 })} kg`;
}

/**
 * Kopf und Reiterleiste fuer alle vier Modell-Reiter (Aufgabe 16). Die
 * fruehere Modellseite (371 Zeilen, fuenf Abschnitte auf einem Bildschirm)
 * zerfaellt in vier Routen -- Stammdaten (page.tsx daneben), Einstellungen,
 * Uebungen, Einzelne Geraete. Nur Stammdaten entsteht in dieser Aufgabe;
 * die anderen drei Ordner liefern Aufgabe 17 und 18.
 *
 * Kein <main> hier -- das traegt (schreibtisch)/layout.tsx bereits fuer
 * alle Kinder (Designsystem: Seite/Layout-Regel aus Aufgabe 4).
 */
export default async function ModellLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: Promise<{ studioId: string; modelId: string }>;
}) {
  const { studioId, modelId } = await params;
  const katalog = await ladeKatalog(studioId);
  const modell = katalog.models.find((eintrag) => eintrag.id === modelId);
  if (!modell) notFound();

  const mitVideo = modell.exercises.filter((uebung) => uebung.hasVideo).length;
  const ohneTag = modell.machines.filter((geraet) => geraet.activeTagCount === 0).length;

  return (
    <>
      <p>
        <Link href={`/portal/${studioId}/geraete`} className={styles.rueckweg}>
          ← Geräte
        </Link>
      </p>
      <h1 className={styles.pageTitle}>{modell.name}</h1>
      <p className={styles.pageLead}>
        {modell.manufacturer ?? "Ohne Herstellerangabe"} · Schritt{" "}
        {kg(modell.weightStepKg)} · ab {kg(modell.minWeightKg)}
        {modell.maxWeightKg === null ? "" : ` bis ${kg(modell.maxWeightKg)}`}
      </p>
      <ModellReiter
        studioId={studioId}
        modelId={modelId}
        einstellungenZusatz={`${modell.settingDefinitions.length} Einstellungen`}
        uebungenZusatz={`${modell.exercises.length} · ${mitVideo} mit Video`}
        instanzenZusatz={`${modell.machines.length} · ${ohneTag} ohne Tag`}
      />
      {children}
    </>
  );
}
