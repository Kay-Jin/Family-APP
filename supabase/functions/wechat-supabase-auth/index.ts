/**
 * Exchange a WeChat mobile OAuth `code` for Supabase session tokens (same contract as Flask POST /auth/wechat-supabase).
 *
 * Deploy: supabase functions deploy wechat-supabase-auth --no-verify-jwt
 *
 * Secrets (Dashboard → Edge Functions → Secrets):
 * - WECHAT_APP_ID, WECHAT_APP_SECRET
 * - SUPABASE_ANON_KEY (project anon / publishable key, for password grant)
 * - WECHAT_DERIVE_SECRET (optional; must match Flask if you use both; defaults to JWT_SECRET then dev default)
 *
 * Auto-injected on hosted Supabase: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
 */
const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function bytesToHex(buf: ArrayBuffer): string {
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function sha256Hex(text: string): Promise<string> {
  const data = new TextEncoder().encode(text);
  const hash = await crypto.subtle.digest("SHA-256", data);
  return bytesToHex(hash);
}

async function derivedPassword(unionId: string, deriveSecret: string): Promise<string> {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(deriveSecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, enc.encode(unionId));
  return bytesToHex(sig).slice(0, 32);
}

async function wechatOAuthExchange(
  code: string,
  appId: string,
  appSecret: string,
): Promise<{ union_id: string; nickname?: string; avatar_url?: string }> {
  const c = code.trim();
  if (!c) throw new Error("code is required");
  if (c === "demo_wechat") {
    return { union_id: "demo_wechat_union", nickname: "Demo WeChat", avatar_url: undefined };
  }
  if (!appId || !appSecret) {
    throw new Error(
      "WeChat app is not configured. Set WECHAT_APP_ID and WECHAT_APP_SECRET, or use code demo_wechat for a local demo.",
    );
  }
  const q = new URLSearchParams({
    appid: appId,
    secret: appSecret,
    code: c,
    grant_type: "authorization_code",
  });
  const r = await fetch(`https://api.weixin.qq.com/sns/oauth2/access_token?${q.toString()}`, {
    method: "GET",
  });
  const data = (await r.json()) as Record<string, unknown>;
  if (data.errcode) {
    throw new Error(String(data.errmsg || "wechat token error"));
  }
  const openid = data.openid as string | undefined;
  if (!openid) throw new Error("WeChat response missing openid");
  const accessToken = data.access_token as string | undefined;
  const unionid = data.unionid as string | undefined;
  const union_id = unionid ? String(unionid) : `openid_${openid}`;
  let nickname: string | undefined;
  let avatar_url: string | undefined;
  if (accessToken) {
    try {
      const u = new URLSearchParams({
        access_token: accessToken,
        openid,
        lang: "zh_CN",
      });
      const r2 = await fetch(`https://api.weixin.qq.com/sns/userinfo?${u.toString()}`, { method: "GET" });
      const info = (await r2.json()) as Record<string, unknown>;
      if (!info.errcode) {
        if (typeof info.nickname === "string") nickname = info.nickname;
        if (typeof info.headimgurl === "string") avatar_url = info.headimgurl;
      }
    } catch {
      /* optional profile */
    }
  }
  return { union_id, nickname, avatar_url };
}

async function ensureSupabaseUser(
  supabaseUrl: string,
  serviceKey: string,
  email: string,
  password: string,
  unionId: string,
): Promise<void> {
  const r = await fetch(`${supabaseUrl}/auth/v1/admin/users`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${serviceKey}`,
      apikey: serviceKey,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      email,
      password,
      email_confirm: true,
      user_metadata: { wechat_unionid: unionId, provider: "wechat" },
    }),
  });
  if (r.ok || r.status === 201) return;
  const text = await r.text();
  const low = text.toLowerCase();
  if (r.status === 422 || low.includes("already") || low.includes("registered")) return;
  throw new Error(`admin create user: ${r.status} ${text}`);
}

async function supabasePasswordToken(
  supabaseUrl: string,
  anonKey: string,
  email: string,
  password: string,
): Promise<{ access_token?: string; refresh_token?: string }> {
  const body = new URLSearchParams({ email, password });
  const r = await fetch(`${supabaseUrl}/auth/v1/token?grant_type=password`, {
    method: "POST",
    headers: {
      apikey: anonKey,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body,
  });
  if (!r.ok) {
    let msg = await r.text();
    try {
      const j = JSON.parse(msg) as Record<string, unknown>;
      msg = String(j.error_description || j.msg || j.message || msg);
    } catch {
      /* keep text */
    }
    throw new Error(msg || "supabase sign-in failed");
  }
  return (await r.json()) as { access_token?: string; refresh_token?: string };
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

  let payload: { code?: string };
  try {
    payload = (await req.json()) as { code?: string };
  } catch {
    return new Response(JSON.stringify({ error: "invalid json" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const code = (payload.code || "").trim();
  if (!code) {
    return new Response(JSON.stringify({ error: "code is required" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const supabaseUrl = (Deno.env.get("SUPABASE_URL") || "").replace(/\/$/, "");
  const serviceKey = (Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "").trim();
  const anonKey = (Deno.env.get("SUPABASE_ANON_KEY") || "").trim();
  const appId = (Deno.env.get("WECHAT_APP_ID") || "").trim();
  const appSecret = (Deno.env.get("WECHAT_APP_SECRET") || "").trim();
  const deriveSecret =
    (Deno.env.get("WECHAT_DERIVE_SECRET") || Deno.env.get("JWT_SECRET") || "dev-secret-change-me").trim();

  if (!supabaseUrl || !serviceKey) {
    return new Response(JSON.stringify({ error: "SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
  if (!anonKey) {
    return new Response(JSON.stringify({ error: "SUPABASE_ANON_KEY secret must be set for password grant" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const wx = await wechatOAuthExchange(code, appId, appSecret);
    const unionId = wx.union_id;
    const digest = (await sha256Hex(unionId)).slice(0, 40);
    const email = `w_${digest}@wechat.familyapp`;
    const password = await derivedPassword(unionId, deriveSecret);
    await ensureSupabaseUser(supabaseUrl, serviceKey, email, password, unionId);
    const tokens = await supabasePasswordToken(supabaseUrl, anonKey, email, password);
    const access = tokens.access_token;
    const refresh = tokens.refresh_token;
    if (!access || !refresh) {
      return new Response(JSON.stringify({ error: "supabase token response incomplete" }), {
        status: 502,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    return new Response(JSON.stringify({ access_token: access, refresh_token: refresh }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    const lower = msg.toLowerCase();
    const status = lower.includes("wechat") || lower.includes("code") ? 400 : 502;
    return new Response(JSON.stringify({ error: msg }), {
      status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
