"use server";

import { redirect } from "next/navigation";
import { z } from "zod";
import { createServerSupabaseClient } from "@/lib/supabase/server";

const emailSchema = z.object({ email: z.string().email() });
const zuruecksetzenSchema = z.object({
  email: z.string().email(),
  token: z.string().regex(/^\d{6}$/, "Der Code besteht aus sechs Ziffern."),
  password: z.string().min(10, "Das Passwort braucht mindestens zehn Zeichen."),
});

export async function passwortVergessenAnfordern(_prev: unknown, formData: FormData) {
  const parsed = emailSchema.safeParse({ email: formData.get("email") });
  if (!parsed.success) return { error: "Bitte eine gueltige E-Mail eingeben." };

  const supabase = await createServerSupabaseClient();
  // Gleiche Antwort in beiden Faellen -- derselbe Grund wie beim
  // frueheren OTP-Login: die Existenz einer Adresse darf sich fuer den
  // Client nicht unterscheiden.
  const { error } = await supabase.auth.resetPasswordForEmail(parsed.data.email);
  if (error) {
    console.error("Passwort-Reset-Mail fehlgeschlagen:", error.message);
  }
  return { sentTo: parsed.data.email };
}

export async function passwortZuruecksetzen(_prev: unknown, formData: FormData) {
  const parsed = zuruecksetzenSchema.safeParse({
    email: formData.get("email"),
    token: formData.get("token"),
    password: formData.get("password"),
  });
  if (!parsed.success) return { error: parsed.error.issues[0]!.message };

  // Die Gleichheitspruefung steht vor dem Supabase-Aufruf: ein Tippfehler in
  // der Wiederholung soll nicht den Code verbrauchen. Ein verbrauchter Code
  // bedeutet eine neue Mail, und der Nutzer weiss nicht, warum.
  const wiederholung = String(formData.get("password2") ?? "");
  if (parsed.data.password !== wiederholung) {
    return { error: "Die beiden Passwörter stimmen nicht überein." };
  }

  const supabase = await createServerSupabaseClient();
  const { error: verifyError } = await supabase.auth.verifyOtp({
    email: parsed.data.email,
    token: parsed.data.token,
    type: "recovery",
  });
  if (verifyError) return { error: "Der Code ist ungueltig oder abgelaufen." };

  const { error: updateError } = await supabase.auth.updateUser({
    password: parsed.data.password,
  });
  if (updateError) return { error: "Das Passwort liess sich nicht setzen." };

  redirect("/");
}
