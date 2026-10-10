import { formatLoad } from "@fitretro/domain/belastung";
import { EINHEIT_ANZEIGE, KATEGORIE_OPTIONEN } from "../../../../bausteine/einstellungVorschlaege";
import Link from "next/link";
import { notFound } from "next/navigation";
import { ladeKatalog, ladeTypen } from "../../../catalog";
import { gymtavoKontext, offenePunkte } from "../../../offen";
import { uebungenStand } from "./uebungen/gymtavo";
import { Modellbild } from "../../../../bausteine/Modellbild";
import { NochZuTun } from "../../../../bausteine/NochZuTun";
import { ModellRahmen } from "./ModellRahmen";
import styles from "../../../../portal.module.css";

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
  // Parallel: die Typliste haengt nicht am Studio-Katalog, und jede
  // Wartezeit hier haelt alle vier Reiter auf.
  const [katalog, alleTypen] = await Promise.all([ladeKatalog(studioId), ladeTypen()]);
  const modell = katalog.models.find((eintrag) => eintrag.id === modelId);
  if (!modell) notFound();

  const ohneTag = modell.machines.filter((geraet) => geraet.activeTagCount === 0).length;
  const fotoUrl = modell.photoPath ? katalog.photoUrls[modell.photoPath] : undefined;
  const typen = katalog.isCatalog ? [] : alleTypen;
  // Der Reiter zaehlt, was am Geraet steht: eigene und Gymtavo-Uebungen.
  const { anzahl: uebungenAnzahl, mitVideo } = uebungenStand(modell, typen, katalog.isCatalog);
  const punkte = offenePunkte(
    studioId,
    modell,
    gymtavoKontext(katalog.isCatalog, typen, modell.catalogModelId),
  );

  return (
    <>
      <p>
        <Link href={`/portal/${studioId}/geraete`} className={styles.rueckweg}>
          ← Geräte
        </Link>
      </p>
      <div className={styles.objektKopf}>
        <Modellbild
          url={fotoUrl}
          name={modell.name}
          leerText="Kein Foto"
          groesse="kopf"
        />
        <div style={{ minWidth: 0 }}>
          <h1 className={styles.pageTitle}>{modell.name}</h1>
          <p className={styles.pageLead}>
            {KATEGORIE_OPTIONEN.find((o) => o.wert === modell.category)?.anzeige}
            {" · "}
            {modell.manufacturer ?? "Ohne Herstellerangabe"} · Schritt{" "}
            {formatLoad(modell.loadStep, modell.loadUnit)} · ab {formatLoad(modell.loadMin, modell.loadUnit)}
            {modell.loadMax === null ? "" : ` bis ${formatLoad(modell.loadMax, modell.loadUnit)}`}
            {modell.secondaryUnit !== null &&
            modell.secondaryMin !== null &&
            modell.secondaryStep !== null
              ? ` · Nebenbelastung ${EINHEIT_ANZEIGE[modell.secondaryUnit]}, ${formatLoad(modell.secondaryMin, modell.secondaryUnit)}${
                  modell.secondaryMax === null ? "" : ` bis ${formatLoad(modell.secondaryMax, modell.secondaryUnit)}`
                }, Schritt ${formatLoad(modell.secondaryStep, modell.secondaryUnit)}`
              : ""}
          </p>
        </div>
      </div>
      {/* Reiter und "Noch zu tun" -- oder, im Ablauf "Gerät hinzufügen"
          (?neu=1), Schrittleiste und Zurück/Weiter (ModellRahmen.tsx). */}
      <ModellRahmen
        studioId={studioId}
        modelId={modelId}
        einstellungenZusatz={`${modell.settingDefinitions.length} Einstellungen`}
        uebungenZusatz={`${uebungenAnzahl} · ${mitVideo} mit Video`}
        instanzenZusatz={`${modell.machines.length} · ${ohneTag} ohne Tag`}
        einstellungenAnzahl={modell.settingDefinitions.length}
        uebungenAnzahl={uebungenAnzahl}
        nochZuTun={<NochZuTun punkte={punkte} />}
        mitInstanzen={!katalog.isCatalog}
      >
        {children}
      </ModellRahmen>
    </>
  );
}
