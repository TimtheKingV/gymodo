"use client";

import { useRef, useState, useTransition } from "react";
import {
  DndContext,
  KeyboardSensor,
  PointerSensor,
  closestCenter,
  useSensor,
  useSensors,
  type DragEndEvent,
} from "@dnd-kit/core";
import {
  SortableContext,
  arrayMove,
  sortableKeyboardCoordinates,
  useSortable,
  verticalListSortingStrategy,
} from "@dnd-kit/sortable";
import { CSS } from "@dnd-kit/utilities";
import type { ActionResult } from "../../../../../actions";
import styles from "../../../../../portal.module.css";
import eigene from "./uebungen.module.css";

type Eintrag = { linkId: string; name: string };

/**
 * "Reihenfolge ändern" (Testnotiz 22.09., #11): statt Hoch/Runter an jeder
 * Karte ein Knopf ueber der Liste, der einen Dialog oeffnet. Darin zieht
 * der Trainer die Uebungen am Griff (≡) in die richtige Reihenfolge und
 * bestaetigt mit "Fertig" -- erst dann geht EINE Server-Aktion raus, nicht
 * eine pro Schritt.
 *
 * Die Reihenfolge ist keine Kosmetik: die erste Uebung ist am Geraet die
 * Vorauswahl des Mitglieds (Canvas-Notiz `note-uebungen`).
 *
 * Ziehen per Maus, Finger und Tastatur (dnd-kit): Tab auf den Griff,
 * Leertaste nimmt auf, Pfeiltasten verschieben, Leertaste legt ab. Das
 * Ziehen startet nur am Griff, damit die Liste auf dem Telefon scrollbar
 * bleibt.
 */
export function ReihenfolgeDialog({
  uebungen,
  speichern,
}: {
  uebungen: Eintrag[];
  speichern: (linkIds: string[]) => Promise<ActionResult>;
}) {
  const dialog = useRef<HTMLDialogElement>(null);
  const [liste, setListe] = useState(uebungen);
  const [gezogen, setGezogen] = useState<string | null>(null);
  const [fehler, setFehler] = useState<string | null>(null);
  const [laeuft, starte] = useTransition();

  const sensoren = useSensors(
    // Kleine Schwelle: ein Tippen auf den Griff ist noch kein Ziehen.
    useSensor(PointerSensor, { activationConstraint: { distance: 4 } }),
    useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates }),
  );

  function oeffnen() {
    // Jedes Oeffnen beginnt beim gespeicherten Stand -- ein abgebrochener
    // Versuch soll beim naechsten Mal nicht wieder auftauchen.
    setListe(uebungen);
    setFehler(null);
    dialog.current?.showModal();
  }

  function schliessen() {
    dialog.current?.close();
  }

  function aufZiehenEnde(ereignis: DragEndEvent) {
    setGezogen(null);
    const { active, over } = ereignis;
    if (!over || active.id === over.id) return;
    setListe((bisher) => {
      const von = bisher.findIndex((eintrag) => eintrag.linkId === active.id);
      const nach = bisher.findIndex((eintrag) => eintrag.linkId === over.id);
      return arrayMove(bisher, von, nach);
    });
  }

  const unveraendert = liste.every((eintrag, i) => eintrag.linkId === uebungen[i]?.linkId);

  function fertig() {
    if (unveraendert) {
      schliessen();
      return;
    }
    setFehler(null);
    starte(async () => {
      const antwort = await speichern(liste.map((eintrag) => eintrag.linkId));
      if (antwort.ok) schliessen();
      else setFehler(antwort.error);
    });
  }

  return (
    <>
      <button type="button" className={styles.secondary} onClick={oeffnen}>
        Reihenfolge ändern
      </button>

      <dialog
        ref={dialog}
        className={eigene.dialog}
        aria-labelledby="reihenfolge-titel"
        // Klick auf den Hintergrund schliesst -- das Ziel ist dann der
        // <dialog> selbst, nicht sein Inhalt.
        onClick={(ereignis) => {
          if (ereignis.target === dialog.current && !laeuft) schliessen();
        }}
      >
        <div className={eigene.dialogKopf}>
          <h2 id="reihenfolge-titel" className={eigene.dialogTitel}>
            Reihenfolge ändern
          </h2>
          <p className={eigene.dialogHinweis}>
            Am Griff ≡ ziehen. Die erste Übung ist am Gerät die Vorauswahl.
          </p>
        </div>

        <DndContext
          sensors={sensoren}
          collisionDetection={closestCenter}
          onDragStart={(ereignis) => setGezogen(String(ereignis.active.id))}
          onDragCancel={() => setGezogen(null)}
          onDragEnd={aufZiehenEnde}
          accessibility={{
            screenReaderInstructions: {
              draggable:
                "Leertaste zum Aufnehmen, Pfeiltasten zum Verschieben, Leertaste zum Ablegen, Escape zum Abbrechen.",
            },
            announcements: {
              onDragStart: ({ active }) => `${name(liste, active.id)} aufgenommen.`,
              onDragOver: ({ active, over }) =>
                over
                  ? `${name(liste, active.id)} auf Platz ${platz(liste, over.id)}.`
                  : `${name(liste, active.id)} ausserhalb der Liste.`,
              onDragEnd: ({ active, over }) =>
                over
                  ? `${name(liste, active.id)} auf Platz ${platz(liste, over.id)} abgelegt.`
                  : `${name(liste, active.id)} abgelegt.`,
              onDragCancel: ({ active }) => `Verschieben von ${name(liste, active.id)} abgebrochen.`,
            },
          }}
        >
          <SortableContext
            items={liste.map((eintrag) => eintrag.linkId)}
            strategy={verticalListSortingStrategy}
          >
            <ol className={eigene.sortierListe} aria-label="Übungen in Reihenfolge">
              {liste.map((eintrag, i) => (
                <SortierZeile
                  key={eintrag.linkId}
                  eintrag={eintrag}
                  nummer={i + 1}
                  zieht={gezogen === eintrag.linkId}
                />
              ))}
            </ol>
          </SortableContext>
        </DndContext>

        <div className={eigene.dialogFuss}>
          {fehler ? (
            <span className={styles.error} role="alert">
              {fehler}
            </span>
          ) : null}
          <button
            type="button"
            className={styles.secondary}
            onClick={schliessen}
            disabled={laeuft}
          >
            Abbrechen
          </button>
          <button type="button" className={styles.primary} onClick={fertig} disabled={laeuft}>
            {laeuft ? "Wird gespeichert …" : "Fertig"}
          </button>
        </div>
      </dialog>
    </>
  );
}

function name(liste: Eintrag[], id: string | number): string {
  return liste.find((eintrag) => eintrag.linkId === id)?.name ?? "Übung";
}

function platz(liste: Eintrag[], id: string | number): number {
  return liste.findIndex((eintrag) => eintrag.linkId === id) + 1;
}

function SortierZeile({
  eintrag,
  nummer,
  zieht,
}: {
  eintrag: Eintrag;
  nummer: number;
  zieht: boolean;
}) {
  const { attributes, listeners, setNodeRef, setActivatorNodeRef, transform, transition } =
    useSortable({ id: eintrag.linkId });

  return (
    <li
      ref={setNodeRef}
      className={zieht ? eigene.sortierZeileZieht : eigene.sortierZeile}
      style={{ transform: CSS.Translate.toString(transform), transition }}
    >
      <span className={eigene.sortierNummer}>{nummer}.</span>
      <span className={eigene.sortierName}>{eintrag.name}</span>
      <button
        ref={setActivatorNodeRef}
        type="button"
        className={eigene.griff}
        aria-label={`${eintrag.name} verschieben`}
        {...attributes}
        {...listeners}
      >
        ≡
      </button>
    </li>
  );
}
