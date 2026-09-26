"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { DomainError, acceptStaffInvite } from "@fitretro/domain";
import { createServerSupabaseClient } from "@/lib/supabase/server";

/** Einladung annehmen (Testnotiz 25.09., #6) und ins Portal des Studios. */
export async function einladungAnnehmen(
  token: string,
  _prev: unknown,
): Promise<{ error: string }> {
  const client = await createServerSupabaseClient();
  let studioId: string | null;
  try {
    studioId = await acceptStaffInvite(client, token);
  } catch (fehler) {
    if (fehler instanceof DomainError && fehler.code === "unauthorized") redirect("/login");
    console.error("Einladung annehmen fehlgeschlagen:", fehler);
    return { error: "Das hat nicht geklappt. Bitte noch einmal." };
  }
  if (!studioId) return { error: "Diese Einladung gilt nicht mehr." };

  revalidatePath("/", "layout");
  redirect(`/portal/${studioId}`);
}
