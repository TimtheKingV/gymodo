import { beforeAll, describe, expect, it } from "vitest";
import { createTagToken, hashTagToken } from "@fitretro/domain";
import {
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";

let studioA: string;
let studioB: string;
let emailA: string;
let tokenA: string;
let tokenB: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioError } = await admin
    .from("studios")
    .insert([{ name: "Tag-Studio A" }, { name: "Tag-Studio B" }])
    .select("id");
  if (studioError) throw studioError;
  studioA = studios[0]!.id;
  studioB = studios[1]!.id;

  emailA = uniqueEmail("tag-a");
  const userA = await createTestUser(emailA);
  const { error: membershipError } = await admin
    .from("studio_memberships")
    .insert({ studio_id: studioA, user_id: userA, role: "member" });
  if (membershipError) throw membershipError;

  tokenA = createTagToken();
  tokenB = createTagToken();
  const { error: tagError } = await admin.from("machine_tags").insert([
    { studio_id: studioA, token_hash: hashTagToken(tokenA), status: "active" },
    { studio_id: studioB, token_hash: hashTagToken(tokenB), status: "active" },
  ]);
  if (tagError) throw tagError;
});

describe("machine_tags", () => {
  it("speichert nur den Hash, nie den Token", async () => {
    const admin = serviceClient();
    const { data } = await admin
      .from("machine_tags")
      .select("token_hash")
      .eq("studio_id", studioA);
    expect(data?.[0]?.token_hash).toBe(hashTagToken(tokenA));
    expect(JSON.stringify(data)).not.toContain(tokenA);
  });

  it("erzwingt Eindeutigkeit des Hashes", async () => {
    const admin = serviceClient();
    const { error } = await admin.from("machine_tags").insert({
      studio_id: studioA,
      token_hash: hashTagToken(tokenA),
      status: "active",
    });
    expect(error).not.toBeNull();
  });

  it("positiv: Nutzer A sieht die Tags seines Studios", async () => {
    const client = await userClient(emailA);
    const { data, error } = await client.from("machine_tags").select("id");
    expect(error).toBeNull();
    expect(data).toHaveLength(1);
  });

  it("cross-tenant: Nutzer A sieht die Tags von Studio B nicht", async () => {
    const client = await userClient(emailA);
    const { data } = await client
      .from("machine_tags")
      .select("id")
      .eq("studio_id", studioB);
    expect(data).toEqual([]);
  });

  it("negativ: Nutzer A kann keinen Tag anlegen", async () => {
    const client = await userClient(emailA);
    const { error } = await client.from("machine_tags").insert({
      studio_id: studioA,
      token_hash: hashTagToken(createTagToken()),
      status: "active",
    });
    expect(error).not.toBeNull();
  });
});
