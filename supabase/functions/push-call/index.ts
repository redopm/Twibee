import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.6'
import { create } from 'https://deno.land/x/djwt@v2.8/mod.ts' // [FIX 1] Moved import to top-level

serve(async (req: any) => {
  try {
    const payload = await req.json();
    const record = payload.record;
    
    if (payload.type !== 'INSERT' || record.status !== 'invited') {
      return new Response(JSON.stringify({ message: "Not an incoming call invite" }), { status: 200 });
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const { data: callLog, error: callError } = await supabaseAdmin
      .from('call_logs')
      .select('inviter_id, is_video, started_at, inviter:profiles!inviter_id(name, avatar_url)')
      .eq('id', record.call_id)
      .single();

    if (callError || !callLog) {
      return new Response(JSON.stringify({ error: "Call not found" }), { status: 400 });
    }

    const callerName = callLog.inviter?.name || 'Someone';
    const callerAvatar = callLog.inviter?.avatar_url || ''; // [FIX 3] Extract avatar URL

    const { data: devices, error: deviceError } = await supabaseAdmin
      .from('linked_devices')
      .select('fcm_token')
      .eq('user_id', record.user_id)
      .not('fcm_token', 'is', null);

    if (deviceError || !devices || devices.length === 0) {
      return new Response(JSON.stringify({ message: "No devices found" }), { status: 200 });
    }

    const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
    if (!serviceAccountJson) {
      throw new Error("Missing FIREBASE_SERVICE_ACCOUNT secret");
    }
    
    const serviceAccount = JSON.parse(serviceAccountJson);
    
    const jwtPayload = {
      iss: serviceAccount.client_email,
      sub: serviceAccount.client_email,
      aud: "https://oauth2.googleapis.com/token",
      iat: Math.floor(Date.now() / 1000),
      exp: Math.floor(Date.now() / 1000) + 3600,
      scope: "https://www.googleapis.com/auth/firebase.messaging"
    };

    const privateKey = serviceAccount.private_key.replace(/\\n/g, '\n');
    const key = await crypto.subtle.importKey(
      "pkcs8",
      pemToBuffer(privateKey),
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["sign"]
    );

    const jwt = await create({ alg: "RS256", typ: "JWT" }, jwtPayload, key);
    
    const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: jwt
      })
    });
    
    const { access_token } = await tokenRes.json();
    const projectId = serviceAccount.project_id;

    // [FIX 2] Use Promise.all for parallel pushing
    const fetchPromises = devices.map((device: any) => {
      const fcmToken = device.fcm_token;
      
      const message = {
        message: {
          token: fcmToken,
          data: {
            call_id: record.call_id,
            caller_id: callLog.inviter_id,
            caller_name: callerName,
            caller_avatar: callerAvatar, // [FIX 3] Added avatar_url as string
            is_video: callLog.is_video ? "true" : "false",
            timestamp: callLog.started_at,
            type: "INCOMING_CALL"
          },
          android: { priority: "high" },
          apns: { headers: { "apns-priority": "10" } }
        }
      };

      return fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${access_token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(message)
      }).then(res => res.json());
    });

    const sendResults = await Promise.all(fetchPromises);

    return new Response(JSON.stringify({ success: true, results: sendResults }), { headers: { "Content-Type": "application/json" } });

  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }
});

function pemToBuffer(pem: string) {
  const base64 = pem.replace(/-----BEGIN PRIVATE KEY-----/g, "").replace(/-----END PRIVATE KEY-----/g, "").replace(/\s/g, "");
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}
