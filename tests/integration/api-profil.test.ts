import { beforeAll, describe, expect, it } from "vitest";
import { GET as bootstrapGET } from "@/app/api/v1/me/bootstrap/route";
import { PUT as profilePUT } from "@/app/api/v1/me/profile/route";
import {
  accessTokenFor,
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";

let email: string;
let userId: string;
let bearer: string;
let fremdeId: string;

function request(rumpf: unknown, auth?: string): Request {
  return new Request("http://localhost/api/v1/me/profile", {
    method: "PUT",
    headers: auth ? { authorization: `Bearer ${auth}` } : {},
    body: JSON.stringify(rumpf),
  });
}

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name: "Profil-API Studio" })
    .select("id")
    .single();
  if (studioError) throw studioError;

  email = uniqueEmail("profil-member");
  userId = await createTestUser(email);
  fremdeId = await createTestUser(uniqueEmail("profil-fremd"));

  const { error: membershipError } = await admin
    .from("studio_memberships")
    .insert({ studio_id: studio.id, user_id: userId, role: "member" });
  if (membershipError) throw membershipError;

  bearer = await accessTokenFor(email);
});

describe("PUT /me/profile", () => {
  it("legt die Zeile an und liefert den geputzten Namen", async () => {
    const response = await profilePUT(request({ displayName: "  Lena  " }, bearer));

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ displayName: "Lena" });
  });

  it("aendert einen bestehenden Namen", async () => {
    await profilePUT(request({ displayName: "Lena" }, bearer));
    const response = await profilePUT(request({ displayName: "Lena W." }, bearer));

    expect(response.status).toBe(200);

    const { data } = await serviceClient()
      .from("profiles")
      .select("display_name")
      .eq("id", userId)
      .single();
    expect(data?.display_name).toBe("Lena W.");
  });

  it("weist einen leeren Namen ab", async () => {
    const response = await profilePUT(request({ displayName: "   " }, bearer));

    expect(response.status).toBe(422);
    const payload = (await response.json()) as { error: { code: string } };
    expect(payload.error.code).toBe("validation_failed");
  });

  it("weist einen Aufruf ohne Anmeldung ab", async () => {
    const response = await profilePUT(request({ displayName: "Lena" }));
    expect(response.status).toBe(401);
  });
});

describe("profiles_insert_own", () => {
  // Die Policy prueft id = auth.uid(). Ohne diese Pruefung koennte
  // jemand eine Zeile fuer ein fremdes Konto anlegen -- und der naechste
  // Bootstrap dieses Kontos truege einen fremden Namen.
  it("laesst keine Zeile fuer ein fremdes Konto zu", async () => {
    const client = await userClient(email);

    const { error } = await client
      .from("profiles")
      .insert({ id: fremdeId, display_name: "Fremd" });

    expect(error).not.toBeNull();
  });
});

describe("GET /me/bootstrap -- member", () => {
  it("liefert den gesetzten Namen", async () => {
    await profilePUT(request({ displayName: "Lena" }, bearer));

    const response = await bootstrapGET(
      new Request("http://localhost/api/v1/me/bootstrap", {
        headers: { authorization: `Bearer ${bearer}` },
      }),
    );

    expect(response.status).toBe(200);
    const payload = (await response.json()) as { member: { displayName: string | null } };
    expect(payload.member.displayName).toBe("Lena");
  });

  it("liefert null fuer ein Mitglied ohne Zeile", async () => {
    const ohneName = uniqueEmail("profil-ohne-name");
    await createTestUser(ohneName);
    const anderesBearer = await accessTokenFor(ohneName);

    const response = await bootstrapGET(
      new Request("http://localhost/api/v1/me/bootstrap", {
        headers: { authorization: `Bearer ${anderesBearer}` },
      }),
    );

    const payload = (await response.json()) as { member: { displayName: string | null } };
    expect(payload.member.displayName).toBeNull();
  });
});
