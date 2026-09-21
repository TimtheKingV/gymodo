import { TestnotizMontage } from "../testnotiz/TestnotizMontage";

/**
 * Huelle ueber dem ganzen Trainerportal -- Studiowahl, Schreibtisch und
 * Halle. Sie gestaltet nichts; sie haengt nur das Testnotiz-Modul in die
 * Seite, und das auch nur im Entwicklungsbau (TestnotizMontage).
 */
export default function PortalLayout({ children }: { children: React.ReactNode }) {
  return (
    <>
      {children}
      <TestnotizMontage />
    </>
  );
}
