import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.6'
import { create } from 'https://deno.land/x/djwt@v2.8/mod.ts'

serve(async (req) => {
  try {
    const payload = await req.json();
    const record = payload.record;
    
    if (payload.type !== 'INSERT' || !record.chat_id || !record.sender_id) {
      return new Response(JSON.stringify({ message: "Invalid payload" }), { status: 200 });
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // Get chat and participants
    const { data: chat, error: chatError } = await supabaseAdmin
      .from('chats')
      .select('is_group, group_name')
      .eq('id', record.chat_id)
      .single();

    if (chatError || !chat) {
      return new Response(JSON.stringify({ error: "Chat not found" }), { status: 400 });
    }

    // Get sender info
    const { data: sender, error: senderError } = await supabaseAdmin
      .from('profiles')
      .select('name, avatar_url')
      .eq('id', record.sender_id)
      .single();

    const senderName = sender?.name || 'Someone';
    
    // Determine notification title and body
    let title = senderName;
    let body = record.message_type === 'text' ? record.content : `Sent a ${record.message_type}`;
    
    if (chat.is_group) {
      title = `${chat.group_name}`;
      body = `${senderName}: ${body}`;
    }

    // Get recipients (all participants except sender)
    const { data: participants, error: partError } = await supabaseAdmin
      .from('chat_participants')
      .select('user_id')
      .eq('chat_id', record.chat_id)
      .neq('user_id', record.sender_id);

    if (partError || !participants || participants.length === 0) {
      return new Response(JSON.stringify({ message: "No other participants" }), { status: 200 });
    }

    const recipientIds = participants.map(p => p.user_id);

    // Get FCM tokens for all recipients
    const { data: devices, error: deviceError } = await supabaseAdmin
      .from('linked_devices')
      .select('fcm_token')
      .in('user_id', recipientIds)
      .not('fcm_token', 'is', null);

    if (deviceError || !devices || devices.length === 0) {
      return new Response(JSON.stringify({ message: "No devices found with FCM tokens" }), { status: 200 });
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

    const fetchPromises = devices.map(device => {
      const fcmToken = device.fcm_token;
      
      const message = {
        message: {
          token: fcmToken,
          data: {
            type: "chat_message",
            chat_id: record.chat_id,
            sender_id: record.sender_id,
            message_id: record.id,
            title: title,
            body: body
          },
          android: { 
            priority: "high"
          },
          apns: { 
            headers: { "apns-priority": "10" },
            payload: {
              aps: {
                "mutable-content": 1
              }
            }
          }
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
    
    // Check if any of the results contain an error from Firebase
    const errors = sendResults.filter(res => res.error);
    if (errors.length > 0) {
      throw new Error("Firebase FCM Error: " + JSON.stringify(errors));
    }

    return new Response(JSON.stringify({ success: true, results: sendResults }), { headers: { "Content-Type": "application/json" } });

  } catch (error) {
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
