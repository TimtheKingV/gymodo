"use client";

import { useActionState } from "react";
import { requestOtp, verifyOtp } from "./actions";

export default function LoginPage() {
  const [requestState, requestAction] = useActionState(requestOtp, null);
  const [verifyState, verifyAction] = useActionState(verifyOtp, null);

  if (requestState && "sentTo" in requestState && requestState.sentTo) {
    return (
      <form action={verifyAction}>
        <input type="hidden" name="email" value={requestState.sentTo} />
        <label htmlFor="token">Code aus der E-Mail</label>
        <input id="token" name="token" inputMode="numeric" required />
        <button type="submit">Anmelden</button>
        {verifyState && "error" in verifyState && <p>{verifyState.error}</p>}
      </form>
    );
  }

  return (
    <form action={requestAction}>
      <label htmlFor="email">E-Mail</label>
      <input id="email" name="email" type="email" required />
      <button type="submit">Code anfordern</button>
      {requestState && "error" in requestState && <p>{requestState.error}</p>}
    </form>
  );
}
