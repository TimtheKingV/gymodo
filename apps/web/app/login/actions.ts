"use server";

import { redirect } from "next/navigation";
import { z } from "zod";
import { createServerSupabaseClient } from "@/lib/supabase/server";

const anmeldenSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

export async function anmelden(_prev: unknown, formData: FormData) {
  const parsed = anmeldenSchema.safeParse({
    email: formData.get("email"),
    password: formData.get("password"),
  });
  if (!parsed.success) return { error: "Bitte E-Mail und Passwort eingeben." };

  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.auth.signInWithPassword(parsed.data);
  if (error) return { error: "E-Mail oder Passwort ist falsch." };

  redirect("/");
}
