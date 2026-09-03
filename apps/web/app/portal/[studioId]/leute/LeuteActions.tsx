"use client";

import type { StudioMember } from "@fitretro/domain";
import { AktionsKnopf } from "../../Form";
import { mitgliedEntfernen, mitgliedRolleAendern } from "../../actions";
import styles from "../../portal.module.css";

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
