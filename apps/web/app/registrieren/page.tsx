import { sichererWeiter } from "../einladung/weiter";
import { RegistrierenFormular } from "./RegistrierenFormular";

/** Server-Huelle wie login/page.tsx: liest ?weiter= (Testnotiz 25.09., #6). */
export default async function RegistrierenPage({
  searchParams,
}: {
  searchParams: Promise<{ weiter?: string }>;
}) {
  const { weiter } = await searchParams;
  return <RegistrierenFormular weiter={sichererWeiter(weiter)} />;
}
