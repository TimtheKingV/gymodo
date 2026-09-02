"use server";

import { redirect } from "next/navigation";
import { z } from "zod";
import { createServerSupabaseClient } from "@/lib/supabase/server";

const registrierenSchema = z.object({
  email: z.string().email("Bitte eine gueltige E-Mail eingeben."),
  password: z.string().min(10, "Das Passwort braucht mindestens zehn Zeichen."),
});
const bestaetigenSchema = z.object({
  email: z.string().email(),
  token: z.string().regex(/^\d{6}$/),
});

export async function registrieren(_prev: unknown, formData: FormData) {
  const parsed = registrierenSchema.safeParse({
    email: formData.get("email"),
    password: formData.get("password"),
  });
  if (!parsed.success) return { error: parsed.error.issues[0]!.message };

  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.auth.signUp({
    email: parsed.data.email,
    password: parsed.data.password,
  });
  if (error) return { error: "Diese Adresse laesst sich nicht registrieren." };

  // Ist die Bestaetigungspflicht aus (lokal, siehe .env.example), liefert
  // signUp bereits eine Session -- dann direkt weiter, sonst zeigt die Seite
  // das Codefeld.
  if (data.session) redirect("/");

  return { sentTo: parsed.data.email };
}

export async function registrierungBestaetigen(_prev: unknown, formData: FormData) {
  const parsed = bestaetigenSchema.safeParse({
    email: formData.get("email"),
    token: formData.get("token"),
  });
  if (!parsed.success) return { error: "Der Code besteht aus sechs Ziffern." };

  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.auth.verifyOtp({
    email: parsed.data.email,
    token: parsed.data.token,
    type: "signup",
  });
  if (error) return { error: "Der Code ist ungueltig oder abgelaufen." };

  redirect("/");
}
