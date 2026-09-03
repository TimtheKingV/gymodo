import { redirect } from "next/navigation";
import {
  DomainError,
  requireStudioStaff,
  type CatalogShipment,
  type CatalogTag,
} from "@fitretro/domain";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { AktionsKnopf } from "../../../Form";
import { tagSperren } from "../../../actions";
import { ladeKatalog } from "../../catalog";
import { Seite } from "../../../bausteine/Seite";
import { Abschnitt } from "../../../bausteine/Abschnitt";
import { Erlaeuterung } from "../../../bausteine/Erlaeuterung";
import { Zeile, Zeilen } from "../../../bausteine/Zeile";
import { Zustand } from "../../../bausteine/Zustand";
import { TagBinden } from "./TagBinden";
import styles from "../../../portal.module.css";

const STATUS_TEXT: Record<string, string> = {
  active: "aktiv",
  revoked: "gesperrt",
  replaced: "ersetzt",
};

const UNAUTORISIERT = "Diese Seite ist Trainern und Inhabern vorbehalten.";

/** Designsystem 10: Zeitangaben in der Studio-Zeitzone, nicht der des Servers. */
function datum(iso: string, timeZone: string): string {
  return new Date(iso).toLocaleDateString("de-DE", {
    weekday: "short",
    day: "numeric",
    month: "long",
    year: "numeric",
    timeZone,
  });
}

function Statusabzeichen({ status }: { status: string }) {
  const klasse =
    status === "active"
      ? `${styles.badge} ${styles.badgeActive}`
      : status === "revoked"
        ? `${styles.badge} ${styles.badgeRevoked}`
        : styles.badge;
  return <span className={klasse}>{STATUS_TEXT[status] ?? status}</span>;
}

/**
 * Die Zusammenfassung einer Lieferung: erst der Vorrat als Zahl (nur bei
 * Geraetetags -- ein Aushangschild gilt sofort und kennt keinen Vorrat),
 * danach die vergebenen Zustaende, aber nur die, die tatsaechlich
 * vorkommen -- eine "0 ersetzt" waere Laerm, den niemand braucht.
 */
function chargenZusammenfassung(
  lieferung: CatalogShipment,
  tags: CatalogTag[],
): React.ReactNode {
  const derCharge = tags.filter((tag) => tag.batchCode === lieferung.batchCode);
  const zaehlung = { active: 0, revoked: 0, replaced: 0 };
  for (const tag of derCharge) {
    if (tag.status in zaehlung) {
      zaehlung[tag.status as keyof typeof zaehlung] += 1;
    }
  }
  const vergeben = zaehlung.active + zaehlung.revoked + zaehlung.replaced;

  const teile: string[] = [];
  if (lieferung.kind === "machine") {
    teile.push(`${lieferung.quantity - vergeben} vorrätig`);
  }
  if (zaehlung.active > 0) teile.push(`${zaehlung.active} aktiv`);
  if (zaehlung.revoked > 0) teile.push(`${zaehlung.revoked} gesperrt`);
  if (zaehlung.replaced > 0) teile.push(`${zaehlung.replaced} ersetzt`);

  const [erste, ...rest] = teile;
  if (!erste) return null;
  return (
    <>
      <strong>{erste}</strong>
      {rest.length > 0 ? `, ${rest.join(", ")}` : null}
    </>
  );
}

export default async function TagsPage({
  params,
}: {
  params: Promise<{ studioId: string }>;
}) {
  const { studioId } = await params;
  const pfad = `/portal/${studioId}/tags`;

  const client = await createServerSupabaseClient();
  const {
    data: { user },
  } = await client.auth.getUser();
  if (!user) redirect("/login");

  let katalog: Awaited<ReturnType<typeof ladeKatalog>>;
  try {
    // Der Katalog selbst prueft keine Rolle (getStudioCatalog traegt kein
    // requireStudioStaff) -- die Geraeteseite braucht ihn auch fuer
    // Mitglieder. Die Tags-Seite ist Trainern vorbehalten, also steht die
    // Pruefung hier, vor der Abfrage, nach dem Muster in leute/page.tsx.
    await requireStudioStaff(client, studioId, user.id, UNAUTORISIERT);
    katalog = await ladeKatalog(studioId);
  } catch (fehler) {
    if (fehler instanceof DomainError && fehler.code === "unauthorized") {
      return (
        <Seite titel="Tags">
          <Zustand art="keinRecht" titel={UNAUTORISIERT} />
        </Seite>
      );
    }
    return (
      <Seite titel="Tags">
        <Zustand
          art="fehler"
          titel={
            fehler instanceof DomainError
              ? fehler.message
              : "Die Tags liessen sich nicht laden."
          }
        />
      </Seite>
    );
  }

  const geraeteNachId = new Map(
    katalog.models.flatMap((modell) =>
      modell.machines.map((geraet) => [
        geraet.id,
        { label: geraet.label, modell: modell.name },
      ]),
    ),
  );

  const freieGeraete = katalog.models.flatMap((modell) =>
    modell.machines
      .filter((geraet) => geraet.status === "active")
      .map((geraet) => ({ id: geraet.id, label: geraet.label, modell: modell.name })),
  );

  const geraeteTagsGeliefert = katalog.shipments
    .filter((lieferung) => lieferung.kind === "machine")
    .reduce((summe, lieferung) => summe + lieferung.quantity, 0);
  const geraeteTags = katalog.tags.filter((tag) => tag.kind === "machine");
  const geraeteTagsVergeben = geraeteTags.length;

  // Charge -> Versanddatum dieser Lieferung, fuer die Aushangschilder-Zeilen
  // unten. Unter der Annahme, dass je Charge hoechstens eine Lieferung an
  // dieses Studio ging -- geprueft ist diese Annahme nicht.
  const versandDatumNachCharge = new Map(
    katalog.shipments.map((lieferung) => [lieferung.batchCode, lieferung.shippedOn]),
  );

  const aushangschilder = katalog.tags.filter((tag) => tag.kind === "studio");
  const aushangschilderChargen = new Set(aushangschilder.map((tag) => tag.batchCode));
  const aushangschilderNotiz =
    aushangschilder.length === 0
      ? undefined
      : aushangschilderChargen.size === 1
        ? `${aushangschilder.length} aus Charge ${[...aushangschilderChargen][0]}`
        : `${aushangschilder.length}`;

  return (
    <Seite
      titel="Tags"
      vorspann="Ein Tag klebt am Gerät und wird gescannt oder angetippt. Das Studio erzeugt keine — Tags kommen als Lieferung. Welcher Tag an welchem Gerät hängt, entscheidet der Scan am Gerät."
    >
      <Abschnitt titel="Lieferungen">
        {katalog.shipments.length === 0 ? (
          <Zustand
            art="leer"
            titel="Noch keine Lieferung."
            naechsterSchritt="Ohne Tag findet ein Mitglied kein Gerät."
          />
        ) : (
          <Zeilen>
            {katalog.shipments.map((lieferung) => (
              <Zeile
                key={lieferung.id}
                titel={`Charge ${lieferung.batchCode}`}
                meta={
                  <>
                    {datum(lieferung.shippedOn, katalog.studioTimezone)} · {lieferung.quantity}{" "}
                    {lieferung.kind === "studio" ? "Aushangschilder" : "Gerätetags"} ·{" "}
                    {chargenZusammenfassung(lieferung, katalog.tags)}
                  </>
                }
              />
            ))}
          </Zeilen>
        )}
      </Abschnitt>
      <Erlaeuterung>
        Der Gerätetag-Vorrat steht als Zahl. Ein vorrätiger Aufkleber lässt
        sich keinem Stück in der Packung zuordnen — 97 gleichlautende Zeilen
        wären keine Auskunft, sondern Lärm. Benennbar wird ein Gerätetag erst
        durch den Scan. Aushangschilder sind ab Lieferung gültig und stehen
        deshalb unten einzeln.
      </Erlaeuterung>

      {/*
        Nicht Teil des Artboards Tags.dc.html (dort stehen nur Lieferungen,
        Vergebene Geraete-Tags und Aushangschilder) -- bewusst beibehalten,
        weil e2e/trainerportal.spec.ts diese Seite benutzt, um einen
        gelieferten Tag ueber "Token vom Tag" / "Gerät auswählen" /
        "Verbinden" an ein Geraet zu binden. Ohne diesen Abschnitt waere
        dieser bereits gruene Test rot, und einen Ersatzweg (Sucher am
        Geraet) gibt es noch nicht.
      */}
      <Abschnitt titel="Tag verbinden" notiz="Token vom Aufkleber abtippen, Gerät wählen.">
        <TagBinden studioId={studioId} pfad={pfad} geraete={freieGeraete} />
      </Abschnitt>

      <Abschnitt
        titel="Vergebene Geräte-Tags"
        notiz={`${geraeteTagsVergeben} von ${geraeteTagsGeliefert}`}
      >
        {/*
          "geliefert", nicht "verbunden" wie im Artboard: machine_tags kennt
          laut 0002_machine_tags.sql nur created_at und revoked_at, kein
          Bindedatum -- "verbunden {Datum}" waere eine Behauptung, die die
          Datenbank nicht stuetzt. created_at ist der Zeitpunkt der
          Chargenanlage, also das Lieferdatum; "gesperrt {Datum}" verwendet
          jetzt tatsaechlich revoked_at. Derselbe Wortlaut wie unten bei den
          Aushangschildern.
        */}
        {geraeteTags.length === 0 ? (
          <Zustand
            art="leer"
            titel="Noch kein Gerätetag vergeben."
            naechsterSchritt="Ein gelieferter Tag wird oben mit einem Gerät verbunden."
          />
        ) : (
          <Zeilen>
            {geraeteTags.map((tag) => {
              const geraet = tag.machineId ? geraeteNachId.get(tag.machineId) : null;
              return (
                <Zeile
                  key={tag.id}
                  titel={
                    <>
                      <Statusabzeichen status={tag.status} />{" "}
                      {geraet ? `${geraet.label} — ${geraet.modell}` : "ohne Gerät"}
                    </>
                  }
                  meta={
                    tag.status === "revoked"
                      ? `Charge ${tag.batchCode} · gesperrt ${datum(tag.revokedAt ?? tag.createdAt, katalog.studioTimezone)} · bleibt als Nachweis stehen`
                      : `Charge ${tag.batchCode} · geliefert ${datum(tag.createdAt, katalog.studioTimezone)}`
                  }
                  aktionen={
                    tag.status !== "revoked" ? (
                      <AktionsKnopf
                        aktion={tagSperren.bind(null, studioId, pfad, tag.id)}
                        label="Sperren"
                        bestaetigung="Wirklich sperren?"
                        art="destructive"
                      />
                    ) : undefined
                  }
                />
              );
            })}
          </Zeilen>
        )}
      </Abschnitt>
      <Erlaeuterung>
        Ein Gerät ohne Tag ist für Mitglieder nicht auffindbar. Verbunden wird
        am Gerät, mit dem Telefon — ein zerkratzter Tag wird dort auch
        ersetzt.
      </Erlaeuterung>

      <Abschnitt titel="Aushangschilder" notiz={aushangschilderNotiz}>
        {aushangschilder.length === 0 ? (
          <Zustand
            art="leer"
            titel="Noch kein Aushangschild."
            naechsterSchritt="Aushangschilder kommen als Lieferung mit ihrer aufgedruckten Nummer."
          />
        ) : (
          <Zeilen>
            {aushangschilder.map((tag) => (
              <Zeile
                key={tag.id}
                titel={
                  <>
                    <Statusabzeichen status={tag.status} /> Schild {tag.batchIndex}
                  </>
                }
                meta={
                  tag.status === "revoked"
                    ? `Charge ${tag.batchCode} · gesperrt ${datum(tag.revokedAt ?? tag.createdAt, katalog.studioTimezone)} · bleibt als Nachweis stehen`
                    : `Charge ${tag.batchCode} · geliefert ${datum(versandDatumNachCharge.get(tag.batchCode) ?? tag.createdAt, katalog.studioTimezone)}`
                }
                aktionen={
                  tag.status !== "revoked" ? (
                    <AktionsKnopf
                      aktion={tagSperren.bind(null, studioId, pfad, tag.id)}
                      label="Sperren"
                      bestaetigung="Wirklich sperren?"
                      art="destructive"
                    />
                  ) : undefined
                }
              />
            ))}
          </Zeilen>
        )}
      </Abschnitt>
      <Erlaeuterung>
        Ein Aushangschild hängt an keinem Gerät — wer es scannt, wird
        Mitglied. Alle Schilder einer Lieferung sind gleichwertig und ab
        Lieferung gültig; welches ihr aufhängt, ist eure Sache. Sperren macht
        genau eines ungültig, die anderen gelten weiter.
      </Erlaeuterung>
    </Seite>
  );
}
