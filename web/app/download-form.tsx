"use client";

import { useState, type FormEvent } from "react";
import { joinWaitlist } from "./actions";
import { copy } from "@/copy";

export function DownloadForm() {
  const [email, setEmail] = useState("");
  const [error, setError] = useState("");
  const [done, setDone] = useState(false);
  const [busy, setBusy] = useState(false);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError("");
    setBusy(true);
    const result = await joinWaitlist(email);
    setBusy(false);
    if ("error" in result && result.error) {
      setError(result.error);
      return;
    }
    setDone(true);
  }

  if (done) {
    return <p className="mt-8 text-[15px] leading-7">{copy.thanks}</p>;
  }

  return (
    <form onSubmit={onSubmit} className="mt-8">
      <div className="flex flex-wrap gap-2">
        <input
          type="email"
          name="email"
          required
          autoComplete="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          placeholder={copy.emailPlaceholder}
          className="min-w-[220px] flex-1 rounded border border-[#ccc] bg-white px-3 py-2 text-sm outline-none"
        />
        <button
          type="submit"
          disabled={busy}
          className="rounded border border-[#ccc] bg-[#f2f2f2] px-4 py-2 text-sm lowercase disabled:opacity-50"
        >
          {copy.go}
        </button>
      </div>
      {error ? <p className="mt-2 text-sm text-red-600">{error}</p> : null}
    </form>
  );
}
