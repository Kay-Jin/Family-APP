/**
 * Dispatch FCM (HTTP v1) to device tokens stored in public.device_push_tokens.
 *
 * Auth: Authorization: Bearer <PUSH_DISPATCH_SECRET> (set in Supabase secrets).
 * Not for browser clients — call from your backend, cron, or automation only.
 */
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { SignJWT, importPKCS8 } from "npm:jose@5";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

type ServiceAccount = {
  type?: string;
  project_id: string;
  private_key: string;
  client_email: string;
};

type PushBody = {
  user_ids: string[];
  title: string;
  body: string;
  data?: Record<string, string>;
};

async function getGoogleAccessToken(sa: ServiceAccount): Promise<string> {
  const pk = sa.private_key.replace(/\\n/g, "\n");
  const key = await importPKCS8(pk, "RS256");
  const now = Math.floor(Date.now() / 1000);
  const assertion = await new SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(sa.client_email)
    .setSubject(sa.client_email)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(key);

  const body = new URLSearchParams({
    grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
    assertion,
  });
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });
  if (!res.ok) {
    const t = await res.text();
    throw new Error(`google oauth token failed: ${res.status} ${t}`);
  }
  const data = (await res.json()) as { access_token?: string };
  if (!data.access_token) throw new Error("google oauth: no access_token");
  return data.access_token;
}

async function sendFcmMessage(
  projectId: string,
  accessToken: string,
  deviceToken: string,
  title: string,
  body: string,
  data?: Record<string, string>,
): Promise<{ ok: boolean; status: number; detail: string }> {
  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
  const message: Record<string, unknown> = {
    token: deviceToken,
    notification: { title, body },
    android: { priority: "HIGH" },
    apns: { headers: { "apns-priority": "10" } },
  };
  if (data && Object.keys(data).length > 0) {
    message.data = data;
  }
  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ message }),
  });
  const text = await res.text();
  return {
    ok: res.ok,
    status: res.status,
    detail: text.slice(0, 500),
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const expected = Deno.env.get("PUSH_DISPATCH_SECRET");
  const auth = req.headers.get("Authorization") ?? "";
  if (!expected || auth !== `Bearer ${expected}`) {
    return new Response(JSON.stringify({ error: "unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const rawJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (!rawJson) {
    return new Response(JSON.stringify({ error: "FIREBASE_SERVICE_ACCOUNT_JSON not set" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  let sa: ServiceAccount;
  try {
    sa = JSON.parse(rawJson) as ServiceAccount;
  } catch {
    return new Response(JSON.stringify({ error: "invalid FIREBASE_SERVICE_ACCOUNT_JSON" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) {
    return new Response(JSON.stringify({ error: "supabase env missing" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  let payload: PushBody;
  try {
    payload = (await req.json()) as PushBody;
  } catch {
    return new Response(JSON.stringify({ error: "invalid json body" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const userIds = Array.isArray(payload.user_ids) ? payload.user_ids.filter((u) => typeof u === "string" && u.length > 0) : [];
  const title = (payload.title ?? "").trim();
  const bodyText = (payload.body ?? "").trim();
  if (userIds.length === 0 || !title || !bodyText) {
    return new Response(
      JSON.stringify({ error: "user_ids (non-empty), title, and body are required" }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  const supabase = createClient(supabaseUrl, serviceKey);
  const { data: rows, error: qErr } = await supabase
    .from("device_push_tokens")
    .select("token, platform, user_id")
    .in("user_id", userIds);

  if (qErr) {
    return new Response(JSON.stringify({ error: qErr.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const tokens = (rows ?? []) as { token: string; platform: string; user_id: string }[];
  if (tokens.length === 0) {
    return new Response(JSON.stringify({ sent: 0, skipped: 0, results: [], message: "no tokens" }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  let accessToken: string;
  try {
    accessToken = await getGoogleAccessToken(sa);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return new Response(JSON.stringify({ error: msg }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const projectId = sa.project_id;
  let dataPayload: Record<string, string> | undefined;
  if (payload.data && typeof payload.data === "object") {
    dataPayload = {};
    for (const [k, v] of Object.entries(payload.data)) {
      dataPayload[k] = typeof v === "string" ? v : JSON.stringify(v);
    }
  }
  const results: unknown[] = [];
  let sent = 0;
  let failed = 0;

  for (const row of tokens) {
    const r = await sendFcmMessage(projectId, accessToken, row.token, title, bodyText, dataPayload);
    results.push({ token_prefix: row.token.slice(0, 12), platform: row.platform, ...r });
    if (r.ok) sent++;
    else failed++;
  }

  return new Response(
    JSON.stringify({
      sent,
      failed,
      total_tokens: tokens.length,
      results,
    }),
    { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
  );
});
