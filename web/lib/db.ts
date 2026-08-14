import { neon } from "@neondatabase/serverless";

function getSql() {
  const url = process.env.DATABASE_URL;
  if (!url) {
    throw new Error("DATABASE_URL is not set");
  }
  return neon(url);
}

let ready = false;

export async function saveEmail(email: string) {
  const sql = getSql();
  if (!ready) {
    await sql`
      CREATE TABLE IF NOT EXISTS downloads (
        id serial primary key,
        email text not null,
        created_at timestamptz default now()
      )
    `;
    ready = true;
  }
  await sql`INSERT INTO downloads (email) VALUES (${email})`;
}
