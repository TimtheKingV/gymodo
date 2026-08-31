import { notFound } from "next/navigation";
import { MAX_PHOTO_BYTES } from "@fitretro/domain";
import { AktionsFormular, AktionsKnopf, Feld } from "../../../Form";
import { ParameterFormular } from "../../../ParameterFormular";
import { VideoUpload } from "../../../VideoUpload";
import {
  fotoHochladen,
  geraetAnlegen,
  geraetStilllegen,
  geraetWiederInBetrieb,
  modellAendern,
  parameterAnlegen,
  parameterLoeschen,
  uebungAnlegen,
  uebungLoesen,
  uebungVerschieben,
} from "../../../actions";
import { ladeKatalog } from "../../catalog";
import { TagAnlegen } from "../../TagAnlegen";
import styles from "../../../portal.module.css";

/** 80,0 statt 80 -- sonst liest sich ein Wechsel auf 82,5 wie ein Formatfehler. */
function kg(wert: number): string {
  return `${wert.toLocaleString("de-DE", { minimumFractionDigits: 1, maximumFractionDigits: 1 })} kg`;
}

export default async function ModellPage({
  params,
}: {
  params: Promise<{ studioId: string; modelId: string }>;
}) {
  const { studioId, modelId } = await params;
  const katalog = await ladeKatalog(studioId);
  const modell = katalog.models.find((eintrag) => eintrag.id === modelId);
  if (!modell) notFound();

  const pfad = `/portal/${studioId}/modelle/${modelId}`;
  const fotoUrl = modell.photoPath ? katalog.photoUrls[modell.photoPath] : undefined;

  return (
    <div className={styles.content}>
      <h1 className={styles.pageTitle}>{modell.name}</h1>
      <p className={styles.pageLead}>
        {modell.manufacturer ?? "Ohne Herstellerangabe"} · Schritt{" "}
        {kg(modell.weightStepKg)} · ab {kg(modell.minWeightKg)}
        {modell.maxWeightKg === null ? "" : ` bis ${kg(modell.maxWeightKg)}`}
      </p>

      {/* 1. Stammdaten und Foto */}
      <section className={styles.section}>
        <div className={styles.sectionHead}>
          <h2 className={styles.sectionTitle}>Stammdaten</h2>
        </div>
        <AktionsFormular
          action={modellAendern.bind(null, studioId, modelId)}
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
                modell.maxWeightKg === null
                  ? ""
                  : String(modell.maxWeightKg).replace(".", ",")
              }
            />
          </div>
        </AktionsFormular>
      </section>

      <section className={styles.section}>
        <div className={styles.sectionHead}>
          <h2 className={styles.sectionTitle}>Foto</h2>
          <span className={styles.sectionNote}>
            Aufnahmedaten werden beim Hochladen entfernt.
          </span>
        </div>
        <div className={styles.sectionBody}>
          <div className={styles.mediaRow}>
            {fotoUrl ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img className={styles.photo} src={fotoUrl} alt={`Foto von ${modell.name}`} />
            ) : (
              <div className={styles.photoEmpty}>Noch kein Foto</div>
            )}
            <div style={{ flex: "1 1 260px" }}>
              <AktionsFormular
                action={fotoHochladen.bind(null, studioId, modelId)}
                submitLabel={fotoUrl ? "Foto ersetzen" : "Foto hochladen"}
              >
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
                    JPEG oder PNG, höchstens {MAX_PHOTO_BYTES / 1024 / 1024} MiB.
                    Ein iPhone wandelt HEIC beim Hochladen selbst um.
                  </span>
                </div>
              </AktionsFormular>
            </div>
          </div>
        </div>
      </section>

      {/* 2. Einstellparameter */}
      <section className={styles.section}>
        <div className={styles.sectionHead}>
          <h2 className={styles.sectionTitle}>Einstellparameter</h2>
          <span className={styles.sectionNote}>
            Was ein Mitglied am Gerät einstellt und sich merken soll.
          </span>
        </div>

        {modell.settingDefinitions.length === 0 ? (
          <div className={styles.empty}>
            <p className={styles.emptyTitle}>Noch kein Einstellparameter.</p>
            <p className={styles.emptyNext}>
              Trag ein, was am Gerät verstellt wird — Sitz, Lehne, Startwinkel.
            </p>
          </div>
        ) : (
          <ul className={styles.rows}>
            {modell.settingDefinitions.map((parameter) => (
              <li key={parameter.id} className={styles.row}>
                <div className={styles.rowMain}>
                  <div className={styles.rowTitle}>{parameter.label}</div>
                  <div className={styles.rowMeta}>
                    <code>{parameter.key}</code> ·{" "}
                    {parameter.kind === "enum"
                      ? (parameter.allowedValues ?? []).join(" · ")
                      : `${parameter.minValue ?? "?"} bis ${parameter.maxValue ?? "?"}${
                          parameter.stepValue ? ` in Schritten von ${parameter.stepValue}` : ""
                        }${parameter.unit ? ` ${parameter.unit}` : ""}`}
                  </div>
                </div>
                <AktionsKnopf
                  aktion={parameterLoeschen.bind(null, studioId, modelId, parameter.id)}
                  label="Löschen"
                  bestaetigung="Wirklich löschen?"
                  art="destructive"
                />
              </li>
            ))}
          </ul>
        )}

        <ParameterFormular action={parameterAnlegen.bind(null, studioId, modelId)} />
      </section>

      {/* 3. Uebungen und Einweisungsvideos */}
      <section className={styles.section}>
        <div className={styles.sectionHead}>
          <h2 className={styles.sectionTitle}>Übungen</h2>
          <span className={styles.sectionNote}>
            Die Reihenfolge bestimmt, was am Gerät zuerst vorgeschlagen wird.
          </span>
        </div>

        {modell.exercises.length === 0 ? (
          <div className={styles.empty}>
            <p className={styles.emptyTitle}>Noch keine Übung.</p>
            <p className={styles.emptyNext}>
              Ohne Übung zeigt der Geräte-Screen nur den Namen. Eine reicht zum
              Anfangen.
            </p>
          </div>
        ) : (
          <ul className={styles.rows}>
            {modell.exercises.map((uebung, index) => {
              const reihenfolge = modell.exercises.map((eintrag) => eintrag.linkId);
              const hoch = [...reihenfolge];
              if (index > 0) {
                [hoch[index - 1], hoch[index]] = [hoch[index]!, hoch[index - 1]!];
              }
              const runter = [...reihenfolge];
              if (index < reihenfolge.length - 1) {
                [runter[index], runter[index + 1]] = [runter[index + 1]!, runter[index]!];
              }

              return (
                <li key={uebung.linkId} className={styles.row}>
                  <div className={styles.rowMain}>
                    <div className={styles.rowTitle}>
                      {index + 1}. {uebung.name}
                    </div>
                    <div className={styles.rowMeta}>
                      {uebung.targetRepsMin}–{uebung.targetRepsMax} Wiederholungen ·{" "}
                      {uebung.hasVideo ? (
                        `Video ${uebung.videoDurationS} s`
                      ) : (
                        <span className={styles.absent}>ohne Video</span>
                      )}
                    </div>
                    <VideoUpload
                      studioId={studioId}
                      modelId={modelId}
                      linkId={uebung.linkId}
                      hatVideo={uebung.hasVideo}
                    />
                  </div>
                  <div className={styles.rowActions}>
                    <AktionsKnopf
                      aktion={uebungVerschieben.bind(null, studioId, modelId, hoch)}
                      label="Hoch"
                    />
                    <AktionsKnopf
                      aktion={uebungVerschieben.bind(null, studioId, modelId, runter)}
                      label="Runter"
                    />
                    <AktionsKnopf
                      aktion={uebungLoesen.bind(null, studioId, modelId, uebung.linkId)}
                      label="Entfernen"
                      bestaetigung="Wirklich entfernen?"
                      art="destructive"
                    />
                  </div>
                </li>
              );
            })}
          </ul>
        )}

        <AktionsFormular
          action={uebungAnlegen.bind(null, studioId, modelId)}
          submitLabel="Übung anlegen"
        >
          <div className={styles.grid}>
            <Feld name="name" label="Name" required placeholder="Latzug breit" />
            <Feld
              name="targetRepsMin"
              label="Wiederholungen ab"
              required
              inputMode="numeric"
              placeholder="8"
            />
            <Feld
              name="targetRepsMax"
              label="bis"
              required
              inputMode="numeric"
              placeholder="12"
            />
          </div>
        </AktionsFormular>
      </section>

      {/* 4. Geraeteinstanzen und Tags */}
      <section className={styles.section}>
        <div className={styles.sectionHead}>
          <h2 className={styles.sectionTitle}>Geräte im Raum</h2>
          <span className={styles.sectionNote}>
            Ohne aktiven Tag findet ein Mitglied das Gerät nicht.
          </span>
        </div>

        {modell.machines.length === 0 ? (
          <div className={styles.empty}>
            <p className={styles.emptyTitle}>Noch kein Gerät angelegt.</p>
            <p className={styles.emptyNext}>
              Ein Modell beschreibt den Typ. Für jedes Gerät im Raum brauchst du
              eine eigene Instanz mit eigener Bezeichnung.
            </p>
          </div>
        ) : (
          <ul className={styles.rows}>
            {modell.machines.map((geraet) => (
              <li key={geraet.id} className={styles.row}>
                <div className={styles.rowMain}>
                  <div className={styles.rowTitle}>
                    {geraet.label}{" "}
                    {geraet.status === "inactive" ? (
                      <span className={styles.badge}>stillgelegt</span>
                    ) : null}
                  </div>
                  <div className={styles.rowMeta}>
                    {geraet.locationNote ?? (
                      <span className={styles.absent}>ohne Standortangabe</span>
                    )}
                    {" · "}
                    {geraet.activeTagCount > 0 ? (
                      `${geraet.activeTagCount} aktiver Tag`
                    ) : (
                      <span className={styles.absent}>kein aktiver Tag</span>
                    )}
                  </div>
                </div>
                <div className={styles.rowActions}>
                  <TagAnlegen studioId={studioId} pfad={pfad} machineId={geraet.id} />
                  {geraet.status === "active" ? (
                    <AktionsKnopf
                      aktion={geraetStilllegen.bind(null, studioId, pfad, geraet.id)}
                      label="Stilllegen"
                      bestaetigung="Wirklich stilllegen?"
                      art="destructive"
                    />
                  ) : (
                    <AktionsKnopf
                      aktion={geraetWiederInBetrieb.bind(null, studioId, pfad, geraet.id)}
                      label="Wieder in Betrieb"
                    />
                  )}
                </div>
              </li>
            ))}
          </ul>
        )}

        <AktionsFormular
          action={geraetAnlegen.bind(null, studioId, modelId)}
          submitLabel="Gerät anlegen"
        >
          <div className={styles.grid}>
            <Feld
              name="label"
              label="Bezeichnung"
              required
              placeholder="12"
              hint="Die Nummer oder der Name, der am Gerät steht."
            />
            <Feld
              name="locationNote"
              label="Standort"
              placeholder="Rückwand links"
              hint="Hilft beim Wiederfinden. Optional."
            />
          </div>
        </AktionsFormular>
      </section>
    </div>
  );
}
