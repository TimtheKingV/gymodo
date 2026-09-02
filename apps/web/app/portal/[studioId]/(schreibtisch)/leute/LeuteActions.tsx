"use client";

import { useState } from "react";
import type { StudioMember } from "@fitretro/domain";
import { AktionsKnopf } from "../../../Form";
import {
  beitrittscodeAktivSetzen,
  beitrittscodeErneuern,
  mitgliedEntfernen,
  mitgliedRolleAendern,
} from "../../../actions";
import styles from "../../../portal.module.css";

export function BeitrittscodeKarte({
  studioId,
  pfad,
  code,
  active,
}: {
  studioId: string;
  pfad: string;
  code: string;
  active: boolean;
}) {
  const [angezeigterCode, setAngezeigterCode] = useState(code);
  const [istAktiv, setIstAktiv] = useState(active);

  return (
    <div className={styles.section}>
      <div className={styles.sectionHead}>
        <h2 className={styles.sectionTitle}>Beitrittscode</h2>
      </div>
      <p className={styles.sectionNote}>
        Wer diesen Code eingibt, wird Mitglied — nie Trainer oder Inhaber.
      </p>
      <p className={styles.token}>
        {angezeigterCode}
        {istAktiv ? null : " · gesperrt"}
      </p>
      <div className={styles.rowActions}>
        <AktionsKnopf
          label="Code erneuern"
          laufendLabel="Wird erneuert …"
          aktion={async () => {
            const antwort = await beitrittscodeErneuern(studioId, pfad);
            if (antwort.ok) {
              setAngezeigterCode(antwort.code);
              setIstAktiv(true);
              return { ok: true };
            }
            return antwort;
          }}
        />
        <AktionsKnopf
          label={istAktiv ? "Code sperren" : "Code entsperren"}
          art={istAktiv ? "destructive" : "secondary"}
          aktion={async () => {
            const antwort = await beitrittscodeAktivSetzen(studioId, pfad, !istAktiv);
            if (antwort.ok) setIstAktiv(!istAktiv);
            return antwort;
          }}
        />
      </div>
    </div>
  );
}

const rollenLabel: Record<StudioMember["role"], string> = {
  owner: "Inhaber",
  trainer: "Trainer",
  member: "Mitglied",
};

export function MitgliedZeile({
  studioId,
  pfad,
  person,
}: {
  studioId: string;
  pfad: string;
  person: StudioMember;
}) {
  if (person.role === "owner") {
    return (
      <li className={styles.row}>
        <div className={styles.rowMain}>
          <div className={styles.rowTitle}>{person.email}</div>
          <div className={styles.rowMeta}>{rollenLabel.owner}</div>
        </div>
      </li>
    );
  }

  const neueRolle: "member" | "trainer" = person.role === "trainer" ? "member" : "trainer";

  return (
    <li className={styles.row}>
      <div className={styles.rowMain}>
        <div className={styles.rowTitle}>{person.email}</div>
        <div className={styles.rowMeta}>{rollenLabel[person.role]}</div>
      </div>
      <div className={styles.rowActions}>
        <AktionsKnopf
          label={person.role === "trainer" ? "Zu Mitglied zurueckstufen" : "Zu Trainer hochstufen"}
          bestaetigung="Wirklich?"
          aktion={() => mitgliedRolleAendern(studioId, pfad, person.userId, neueRolle)}
        />
        <AktionsKnopf
          label="Entfernen"
          art="destructive"
          bestaetigung="Wirklich entfernen?"
          aktion={() => mitgliedEntfernen(studioId, pfad, person.userId)}
        />
      </div>
    </li>
  );
}
