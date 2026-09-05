import { notFound } from "next/navigation";
import { MAX_PHOTO_BYTES } from "@fitretro/domain";
import { AktionsFormular, Feld } from "../../../../Form";
import { fotoHochladen, modellAendern, type ActionResult } from "../../../../actions";
import { ladeKatalog } from "../../../catalog";
import styles from "../../../../portal.module.css";

/**
 * Stammdaten und Foto in einem Formular, mit einer Akzentflaeche
 * ("Änderungen speichern") -- ein Reiter, ein Formular (Struktur-Spec
 * Abschnitt 1). modellAendern und fotoHochladen bleiben unveraendert, wie
 * von Aufgabe 16 verlangt; diese Funktion reicht beide nur nacheinander an
 * dieselbe Absende-Aktion durch. Das Foto ist optional: ohne gewaehlte
 * Datei laeuft nur modellAendern.
 *
 * Eine Einschraenkung, die vorher nicht galt: schlaegt fotoHochladen nach
 * einem erfolgreichen modellAendern fehl, meldet das Formular insgesamt
 * "nicht geklappt", obwohl die Stammdaten schon gespeichert (und
 * revalidiert) sind. Getrennte Formulare hatten dieses Problem nicht --
 * dafuer aber zwei Akzentflaechen auf einem Bildschirm, was die
 * Struktur-Spec fuer einen Reiter ausschliesst.
 */
async function stammdatenUndFotoSpeichern(
  studioId: string,
  modelId: string,
  _prev: unknown,
  formData: FormData,
): Promise<ActionResult> {
  "use server";
  const stammdaten = await modellAendern(studioId, modelId, _prev, formData);
  if (!stammdaten.ok) return stammdaten;

  const datei = formData.get("photo");
  if (datei instanceof File && datei.size > 0) {
    return fotoHochladen(studioId, modelId, _prev, formData);
  }
  return stammdaten;
}

export default async function ModellStammdatenPage({
  params,
}: {
  params: Promise<{ studioId: string; modelId: string }>;
}) {
  const { studioId, modelId } = await params;
  const katalog = await ladeKatalog(studioId);
  const modell = katalog.models.find((eintrag) => eintrag.id === modelId);
  if (!modell) notFound();

  const fotoUrl = modell.photoPath ? katalog.photoUrls[modell.photoPath] : undefined;

  return (
    <section className={styles.section}>
      <AktionsFormular
        action={stammdatenUndFotoSpeichern.bind(null, studioId, modelId)}
        submitLabel="Änderungen speichern"
      >
        <div className={styles.grid}>
          <Feld name="name" label="Name" required defaultValue={modell.name} />
          <Feld
            name="manufacturer"
            label="Hersteller"
            defaultValue={modell.manufacturer ?? ""}
          />
          <Feld
            name="weightStepKg"
            label="Gewichtsschritt"
            required
            inputMode="decimal"
            defaultValue={String(modell.weightStepKg).replace(".", ",")}
          />
          <Feld
            name="minWeightKg"
            label="Minimum"
            inputMode="decimal"
            defaultValue={String(modell.minWeightKg).replace(".", ",")}
          />
          <Feld
            name="maxWeightKg"
            label="Maximum"
            inputMode="decimal"
            defaultValue={
              modell.maxWeightKg === null ? "" : String(modell.maxWeightKg).replace(".", ",")
            }
          />
        </div>
        <div className={styles.mediaRow}>
          {fotoUrl ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img className={styles.photo} src={fotoUrl} alt={`Foto von ${modell.name}`} />
          ) : (
            <div className={styles.photoEmpty}>Noch kein Foto</div>
          )}
          <div style={{ flex: "1 1 260px" }}>
            <div className={styles.field}>
              <label className={styles.label} htmlFor="photo">
                Bilddatei
              </label>
              <input
                id="photo"
                name="photo"
                type="file"
                accept="image/jpeg,image/png"
                className={styles.input}
                aria-describedby="photo-hint"
              />
              <span id="photo-hint" className={styles.hint}>
                JPEG oder PNG, höchstens {MAX_PHOTO_BYTES / 1024 / 1024} MiB. Ein iPhone wandelt
                HEIC beim Hochladen selbst um. Leer lassen, um das Foto unveraendert zu lassen.
              </span>
            </div>
          </div>
        </div>
      </AktionsFormular>
    </section>
  );
}
