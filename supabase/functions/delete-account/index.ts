// Supabase Edge Function: delete-account
//
// Deploys to: https://<project>.supabase.co/functions/v1/delete-account
//
// Authenticated users call this to permanently delete their own account.
// Because the `auth.users` foreign keys on `moments`, `user_focus`, and
// `user_custom_tags` are `on delete cascade`, deleting the auth user
// removes all of their data automatically.
//
// Deploy with the Supabase CLI:
//   supabase functions deploy delete-account --no-verify-jwt=false
//
// Set the secrets the function needs (only run once per project):
//   supabase secrets set SUPABASE_SERVICE_ROLE_KEY=<your service role key>
//
// SUPABASE_URL is provided automatically by the runtime.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const jwt = authHeader.replace(/^Bearer\s+/i, "").trim();
  if (!jwt) return json({ error: "Missing access token" }, 401);

  const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
  const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!SUPABASE_URL || !SERVICE_ROLE) {
    return json({ error: "Server not configured" }, 500);
  }

  // Verify the JWT belongs to a real user before doing anything destructive.
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: userResp, error: userErr } = await admin.auth.getUser(jwt);
  if (userErr || !userResp?.user) {
    return json({ error: "Invalid or expired session" }, 401);
  }

  const userId = userResp.user.id;

  // Delete the auth user. ON DELETE CASCADE on our tables removes the rest.
  const { error: deleteErr } = await admin.auth.admin.deleteUser(userId);
  if (deleteErr) {
    return json({ error: deleteErr.message }, 500);
  }

  return json({ ok: true, deleted: userId });
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
