
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};

Deno.serve(async req => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }

  try {
    const b = await req.json();

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const anon = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!
    );

    if (!["apply", "login"].includes(b.action)) {
      throw Error("Invalid action.");
    }

    let email = b.email;

    if (b.action === "login") {
      const { data: p, error: pe } = await admin
        .from("profiles")
        .select("id")
        .eq("username", String(b.username || "").toLowerCase().trim())
        .eq("account_status", "Approved")
        .maybeSingle();

      if (pe || !p) throw Error("Invalid or expired code.");

      const { data: u, error: ue } =
        await admin.auth.admin.getUserById(p.id);

      if (ue || !u.user?.email) {
        throw Error("Invalid or expired code.");
      }

      email = u.user.email;
    }

    if (!email || !b.token) {
      throw Error("Missing verification details.");
    }

    const { data, error } = await anon.auth.verifyOtp({
      email,
      token: String(b.token),
      type: "email"
    });

    if (error || !data.user) {
      throw Error("Invalid or expired verification code.");
    }

    if (b.action === "apply") {
      const metadata = data.user.user_metadata || {};

      const { error: up } = await admin
        .from("profiles")
        .update({
          username: String(metadata.username || "").toLowerCase().trim(),
          display_name: metadata.display_name || metadata.username || "",
          department: metadata.department || "Both"
        })
        .eq("id", data.user.id);

      if (up) throw up;
    }

    return Response.json({
      ok: true,
      access_token: data.session?.access_token,
      refresh_token: data.session?.refresh_token
    }, { headers: cors });

  } catch (e) {
    return Response.json({
      error: (e as Error).message
    }, { status: 400, headers: cors });
  }
});
