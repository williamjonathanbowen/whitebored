"use server";

import { saveEmail } from "@/lib/db";

export async function startDownload(email: string) {
  const trimmed = email.trim().toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmed)) {
    return { error: "need a real email" };
  }

  try {
    await saveEmail(trimmed);
  } catch {
    return { error: "could not save that. try again." };
  }

  return { url: process.env.DOWNLOAD_URL || "/whitebored.zip" };
}
