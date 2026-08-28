"use server";

import { redirect } from "next/navigation";
import { z } from "zod";
import { createServerSupabaseClient } from "@/lib/supabase/server";

const emailSchema = z.object({ email: z.string().email() });
const otpSchema = z.object({
  email: z.string().email(),
  token: z.string().regex(/^\d{6}$/),
});

export async function requestOtp(_prev: unknown, formData: FormData) {
  const parsed = emailSchema.safeParse({ email: formData.get("email") });
  if (!parsed.success) return { error: "Bitte eine gueltige E-Mail eingeben." };

  const supabase = await createServerSupabaseClient();
  // Die Antwort an den Client wird absichtlich in beiden Faellen gleich
  // gehalten: Ob die Adresse existiert oder nicht, darf sich fuer den
  // Client nicht unterscheiden (User-Enumeration). Ein nicht existierender
  // Nutzer bekommt spaetestens bei verifyOtp einen Fehler ("Der Code ist
  // ungueltig oder abgelaufen."). Serverseitig wird ein echter Sendefehler
  // (Rate-Limit, SMTP-Ausfall) aber geloggt, damit er fuer den Betreiber
  // sichtbar bleibt - niemals die E-Mail-Adresse oder einen Token/Code.
  const { error } = await supabase.auth.signInWithOtp({
    email: parsed.data.email,
    options: { shouldCreateUser: false },
  });
  if (error) {
    console.error("OTP-Versand fehlgeschlagen:", error.message);
  }

  return { sentTo: parsed.data.email };
}

export async function verifyOtp(_prev: unknown, formData: FormData) {
  const parsed = otpSchema.safeParse({
    email: formData.get("email"),
    token: formData.get("token"),
  });
  if (!parsed.success) return { error: "Der Code besteht aus sechs Ziffern." };

  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.auth.verifyOtp({
    email: parsed.data.email,
    token: parsed.data.token,
    type: "email",
  });
  if (error) return { error: "Der Code ist ungueltig oder abgelaufen." };

  redirect("/");
}
