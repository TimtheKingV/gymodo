import type { SupabaseClient } from "@supabase/supabase-js";
import { requireUserId } from "./auth.js";
import { DomainError } from "./errors.js";
import { requireStudioStaff } from "./studio.js";

/**
 * Mitarbeiter einladen per Link (0045, Testnotiz 25.09., #6).
 *
 * Der Token entsteht in der Datenbank und wird dort nur als Hash
 * gespeichert. Diese Datei reicht ihn einmal nach oben durch -- beim
 * Erzeugen -- und nimmt ihn beim Oeffnen des Links wieder entgegen.
 */

const TOKEN_FORM = /^[0-9a-f]{64}$/;

/** Die Form, die create_staff_invite erzeugt. Alles andere ist kein Link
    von uns und braucht keinen Weg zur Datenbank. */
export function istEinladungsToken(token: string): boolean {
  return TOKEN_FORM.test(token);
}

export type StaffInvite = {
  id: string;
  createdAt: string;
  expiresAt: string;
};

export type StaffInviteInfo = {
  studioName: string;
  expiresAt: string;
};

export async function createStaffInvite(
  client: SupabaseClient,
  studioId: string,
): Promise<string> {
  const userId = await requireUserId(client);
  await requireStudioStaff(client, studioId, userId, "Nur Trainer und Inhaber laden ein.");

  const { data, error } = await client.rpc("create_staff_invite", { p_studio_id: studioId });
  if (error || typeof data !== "string") {
    throw new DomainError("internal", error?.message ?? "Keine Einladung erzeugt.");
  }
  return data;
}

/** Die offenen Einladungen -- benutzte, zurueckgezogene und abgelaufene
    stehen nicht mehr in der Liste, sie tun ohnehin nichts mehr. */
export async function listStaffInvites(
  client: SupabaseClient,
  studioId: string,
): Promise<StaffInvite[]> {
  const userId = await requireUserId(client);
  await requireStudioStaff(client, studioId, userId);

  const { data, error } = await client
    .from("staff_invites")
    .select("id, created_at, expires_at")
    .eq("studio_id", studioId)
    .is("accepted_at", null)
    .is("revoked_at", null)
    .gt("expires_at", new Date().toISOString())
    .order("created_at", { ascending: false });
  if (error) throw new DomainError("internal", error.message);

  return (data ?? []).map((zeile: { id: string; created_at: string; expires_at: string }) => ({
    id: zeile.id,
    createdAt: zeile.created_at,
    expiresAt: zeile.expires_at,
  }));
}

export async function revokeStaffInvite(client: SupabaseClient, inviteId: string): Promise<void> {
  await requireUserId(client);
  const { error } = await client.rpc("revoke_staff_invite", { p_invite_id: inviteId });
  if (error) throw new DomainError("not_found", "Diese Einladung gibt es nicht.");
}

/**
 * Was die Einladungsseite zeigt, auch ohne Anmeldung. `null` heisst: gilt
 * nicht -- unbekannt, abgelaufen, benutzt und zurueckgezogen sehen gleich
 * aus (0045).
 */
export async function getStaffInviteInfo(
  client: SupabaseClient,
  token: string,
): Promise<StaffInviteInfo | null> {
  if (!istEinladungsToken(token)) return null;
  const { data, error } = await client.rpc("staff_invite_info", { p_token: token });
  if (error) throw new DomainError("internal", error.message);
  const zeile = (data ?? [])[0] as { studio_name: string; expires_at: string } | undefined;
  return zeile ? { studioName: zeile.studio_name, expiresAt: zeile.expires_at } : null;
}

/** Nimmt an und liefert das Studio -- oder `null`, wenn der Link nicht
    (mehr) gilt. */
export async function acceptStaffInvite(
  client: SupabaseClient,
  token: string,
): Promise<string | null> {
  await requireUserId(client);
  if (!istEinladungsToken(token)) return null;
  const { data, error } = await client.rpc("accept_staff_invite", { p_token: token });
  if (error) throw new DomainError("internal", error.message);
  const zeile = (data ?? [])[0] as { studio_id: string } | undefined;
  return zeile?.studio_id ?? null;
}
