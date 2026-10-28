import { createHash } from "node:crypto";
import { HttpsError } from "firebase-functions/v2/https";

export const hash = (value: string) =>
  createHash("sha256").update(value).digest("hex");
export function record(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value))
    throw new HttpsError("invalid-argument", "Invalid request.");
  return value as Record<string, unknown>;
}
export function text(value: unknown, field: string, max: number): string {
  if (
    typeof value !== "string" ||
    !value.trim() ||
    value.trim().length > max ||
    /[\u0000-\u001f\u007f]/.test(value)
  )
    throw new HttpsError("invalid-argument", `Invalid ${field}.`);
  return value.trim();
}
export function identifier(value: unknown): string {
  const id = text(value, "identifier", 128);
  if (!/^[A-Za-z0-9_-]+$/.test(id))
    throw new HttpsError("invalid-argument", "Invalid identifier.");
  return id;
}
export function commandId(value: unknown): string {
  const id = text(value, "command ID", 36);
  if (
    !/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
      id,
    )
  )
    throw new HttpsError("invalid-argument", "Invalid command ID.");
  return id;
}
export function nonceHash(value: unknown): string {
  const nonce = text(value, "one-use code", 43);
  if (
    !/^[A-Za-z0-9_-]{43}$/.test(nonce) ||
    Buffer.from(nonce, "base64url").toString("base64url") !== nonce
  )
    throw new HttpsError("invalid-argument", "Invalid one-use code.");
  return hash(nonce);
}
export function emailHash(value: unknown): string {
  const email = text(value, "recipient email", 254).toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))
    throw new HttpsError("invalid-argument", "Invalid recipient email.");
  return hash(email);
}
