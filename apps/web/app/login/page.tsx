import { sichererWeiter } from "../einladung/weiter";
import { LoginFormular } from "./LoginFormular";

/**
 * Server-Huelle um das Formular: sie liest ?weiter= (Testnotiz 25.09.,
 * #6), ohne dass das Formular useSearchParams und damit eine
 * Suspense-Grenze braucht.
 */
export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ weiter?: string }>;
}) {
  const { weiter } = await searchParams;
  return <LoginFormular weiter={sichererWeiter(weiter)} />;
}
