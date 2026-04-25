// Supabase Edge Function: contact
//
// Public endpoint. Accepts a contact form submission and stores it in
// `public.contact_messages` using the service role (bypasses RLS).
//
// Deploy with:
//   npx supabase functions deploy contact --no-verify-jwt
//
// (We use --no-verify-jwt because the contact form is open to anonymous
// visitors — the function does its own simple validation and rate limiting.)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Very light in-memory throttle (per warm instance) — 10 / 5min / IP.
const recent = new Map<string, number[]>();
const WINDOW_MS = 5 * 60 * 1000;
const MAX_PER_WINDOW = 10;

function rateLimited(ip: string): boolean {
  const now = Date.now();
  const arr = (recent.get(ip) ?? []).filter((t) => now - t < WINDOW_MS);
  if (arr.length >= MAX_PER_WINDOW) {
    recent.set(ip, arr);
    return true;
  }
  arr.push(now);
  recent.set(ip, arr);
  return false;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const ip = req.headers.get("x-forwarded-for")?.split(",")[0].trim() ?? "unknown";
  if (rateLimited(ip)) {
    return json({ error: "Too many messages, please try again later." }, 429);
  }

  let body: Record<string, unknown> = {};
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }

  // Honeypot — bots fill this; humans never see it.
  if (typeof body.website === "string" && body.website.length > 0) {
    return json({ ok: true });
  }

  const name = sanitize(body.name, 200);
  const email = sanitize(body.email, 320);
  const message = sanitize(body.message, 5000);

  if (!message || message.length < 5) {
    return json({ error: "Please enter a message." }, 400);
  }
  if (email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return json({ error: "Please enter a valid email." }, 400);
  }

  const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
  const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!SUPABASE_URL || !SERVICE_ROLE) {
    return json({ error: "Server not configured" }, 500);
  }

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { error } = await admin.from("contact_messages").insert({
    name: name || null,
    email: email || null,
    message,
    user_agent: req.headers.get("user-agent")?.slice(0, 500) ?? null,
    ip,
  });

  if (error) {
    console.error("contact insert error:", error);
    return json({ error: "Could not save message" }, 500);
  }

  return json({ ok: true });
});

function sanitize(value: unknown, max: number): string {
  if (typeof value !== "string") return "";
  return value.replace(/\u0000/g, "").trim().slice(0, max);
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
