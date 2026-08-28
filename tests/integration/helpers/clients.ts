import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import "dotenv/config";

function required(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`Umgebungsvariable ${name} fehlt`);
  return value;
}

const URL = required("SUPABASE_URL");
const ANON = required("SUPABASE_ANON_KEY");
const SERVICE = required("SUPABASE_SERVICE_ROLE_KEY");

export function serviceClient(): SupabaseClient {
  return createClient(URL, SERVICE, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export const TEST_PASSWORD = "test-passwort-1234";

export async function createTestUser(email: string): Promise<string> {
  const admin = serviceClient();
  const { data, error } = await admin.auth.admin.createUser({
    email,
    password: TEST_PASSWORD,
    email_confirm: true,
  });
  if (error) throw error;
  return data.user.id;
}

export async function userClient(email: string): Promise<SupabaseClient> {
  const client = createClient(URL, ANON, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { error } = await client.auth.signInWithPassword({
    email,
    password: TEST_PASSWORD,
  });
  if (error) throw error;
  return client;
}

export function uniqueEmail(prefix: string): string {
  return `${prefix}-${crypto.randomUUID()}@example.test`;
}
