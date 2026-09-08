import { notFound } from "next/navigation";
import { fotoHochladen, modellAendern, type ActionResult } from "../../../../actions";
import { ladeKatalog } from "../../../catalog";
import { StammdatenFormular } from "./StammdatenFormular";
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
      <StammdatenFormular
        action={stammdatenUndFotoSpeichern.bind(null, studioId, modelId)}
        modell={modell}
        fotoUrl={fotoUrl}
      />
    </section>
  );
}
