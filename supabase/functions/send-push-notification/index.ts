type NotificationRow = {
  id: string;
  user_id: string;
  type: 'comment_on_record' | 'reply_to_comment';
  battle_id: string;
  record_id: string;
  actor_user_id: string;
};

type WebhookPayload = {
  record?: NotificationRow;
};

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const firebaseProjectId = Deno.env.get('FIREBASE_PROJECT_ID') ?? '';
const firebaseClientEmail = Deno.env.get('FIREBASE_CLIENT_EMAIL') ?? '';
const firebasePrivateKey = (
  Deno.env.get('FIREBASE_PRIVATE_KEY') ?? ''
).replace(/\\n/g, '\n');
const webhookSecret = Deno.env.get('PUSH_WEBHOOK_SECRET') ?? '';

Deno.serve(async (request) => {
  if (request.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  try {
    console.log('send-push-notification invoked');

    if (
      webhookSecret &&
      request.headers.get('x-webhook-secret') !== webhookSecret
    ) {
      console.error('webhook secret mismatch');
      return new Response('Unauthorized', { status: 401 });
    }

    const payload = (await request.json()) as WebhookPayload | NotificationRow;
    const notification = 'record' in payload ? payload.record : payload;

    if (!notification?.user_id) {
      return Response.json({ ok: false, error: 'notification record missing' }, {
        status: 400,
      });
    }

    const [tokens, actorName] = await Promise.all([
      fetchPushTokens(notification.user_id),
      fetchActorName(notification.actor_user_id),
    ]);

    console.log(
      `notification=${notification.id} user=${notification.user_id} tokens=${tokens.length}`,
    );

    if (tokens.length === 0) {
      return Response.json({ ok: true, sent: 0 });
    }

    const accessToken = await fetchFirebaseAccessToken();
    const title = notification.type === 'reply_to_comment'
      ? `${actorName}さんから返信が届きました`
      : `${actorName}さんからコメントが届きました`;

    const results = await Promise.all(
      tokens.map((token) => sendMessage(accessToken, token, notification, title)),
    );

    return Response.json({
      ok: true,
      sent: results.filter((result) => result).length,
      failed: results.filter((result) => !result).length,
    });
  } catch (error) {
    console.error('send push notification error', error);
    return Response.json({ ok: false, error: String(error) }, { status: 500 });
  }
});

async function fetchPushTokens(userId: string): Promise<string[]> {
  const response = await fetch(
    `${supabaseUrl}/rest/v1/push_tokens?select=token&user_id=eq.${userId}`,
    {
      headers: {
        apikey: serviceRoleKey,
        authorization: `Bearer ${serviceRoleKey}`,
      },
    },
  );

  if (!response.ok) {
    throw new Error(`fetch push tokens failed: ${await response.text()}`);
  }

  const rows = await response.json() as Array<{ token: string }>;
  return rows.map((row) => row.token).filter(Boolean);
}

async function fetchActorName(actorUserId: string): Promise<string> {
  const response = await fetch(
    `${supabaseUrl}/rest/v1/profiles?select=name&id=eq.${actorUserId}&limit=1`,
    {
      headers: {
        apikey: serviceRoleKey,
        authorization: `Bearer ${serviceRoleKey}`,
      },
    },
  );

  if (!response.ok) return '誰か';

  const rows = await response.json() as Array<{ name: string | null }>;
  return rows[0]?.name || '誰か';
}

async function fetchFirebaseAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const assertion = await createJwt({
    iss: firebaseClientEmail,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  });

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });

  if (!response.ok) {
    throw new Error(`firebase token failed: ${await response.text()}`);
  }

  const json = await response.json() as { access_token: string };
  return json.access_token;
}

async function sendMessage(
  accessToken: string,
  token: string,
  notification: NotificationRow,
  title: string,
): Promise<boolean> {
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${firebaseProjectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        authorization: `Bearer ${accessToken}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token,
          notification: {
            title,
            body: '掲示板を確認しましょう',
          },
          data: {
            type: notification.type,
            notification_id: notification.id,
            battle_id: notification.battle_id,
            record_id: notification.record_id,
          },
          android: {
            notification: {
              channel_id: 'default',
              sound: 'default',
            },
          },
          apns: {
            payload: {
              aps: {
                sound: 'default',
              },
            },
          },
        },
      }),
    },
  );

  if (!response.ok) {
    console.error('fcm send failed', await response.text());
    return false;
  }

  return true;
}

async function createJwt(payload: Record<string, string | number>) {
  const header = { alg: 'RS256', typ: 'JWT' };
  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const unsignedJwt = `${encodedHeader}.${encodedPayload}`;
  const key = await importPrivateKey(firebasePrivateKey);
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsignedJwt),
  );

  return `${unsignedJwt}.${base64UrlEncode(signature)}`;
}

async function importPrivateKey(privateKey: string) {
  const pem = privateKey
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '');
  const binary = Uint8Array.from(atob(pem), (char) => char.charCodeAt(0));

  return await crypto.subtle.importKey(
    'pkcs8',
    binary,
    {
      name: 'RSASSA-PKCS1-v1_5',
      hash: 'SHA-256',
    },
    false,
    ['sign'],
  );
}

function base64UrlEncode(value: string | ArrayBuffer) {
  const bytes = typeof value === 'string'
    ? new TextEncoder().encode(value)
    : new Uint8Array(value);
  let binary = '';

  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }

  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
