"use server";

import { revalidatePath } from "next/cache";
import { DomainError, joinStudioByCode } from "@fitretro/domain";
import { createServerSupabaseClient } from "@/lib/supabase/server";

export async function beitreten(
  _prev: unknown,
  formData: FormData,
): Promise<{ ok: true } | { ok: false; error: string }> {
  const code = String(formData.get("code") ?? "");
  const client = await createServerSupabaseClient();
  try {
    await joinStudioByCode(client, code);
  } catch (fehler) {
    if (fehler instanceof DomainError) return { ok: false, error: fehler.message };
    console.error("Beitritt fehlgeschlagen:", fehler);
    return { ok: false, error: "Das hat nicht geklappt. Bitte noch einmal." };
  }
  revalidatePath("/");
  return { ok: true };
}
