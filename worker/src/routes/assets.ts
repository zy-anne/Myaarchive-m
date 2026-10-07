import { Hono } from 'hono';
import { createMiddleware } from 'hono/factory';
import { Env } from '../types';
import { AuthUtil } from '../auth';

type Variables = { userId: string };

export const assetsRouter = new Hono<{ Bindings: Env; Variables: Variables }>();

// ─── Limits & validation ─────────────────────────────────────────────

/** Folders under a user's scope that clients may upload into. */
const ALLOWED_PREFIXES = new Set(['covers', 'avatars', 'gallery', 'characters', 'volumes', 'icons']);

const CONTENT_TYPE_EXT: Record<string, string> = {
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
  'image/gif': '.gif',
};

const MAX_UPLOAD_BYTES = 10 * 1024 * 1024; // 10 MB

const DEFAULT_URL_TTL_SECONDS = 3600;
const MIN_URL_TTL_SECONDS = 60;
const MAX_URL_TTL_SECONDS = 24 * 3600;

/** Every key this API creates lives under `u/<userId>/`. */
const USER_SCOPE = 'u/';

const SAFE_KEY = /^[A-Za-z0-9._\/-]+$/;

function isValidKey(key: string): boolean {
  return (
    key.length > 0 &&
    key.length <= 300 &&
    SAFE_KEY.test(key) &&
    !key.startsWith('/') &&
    !key.includes('..') &&
    !key.includes('//')
  );
}

function isOwnKey(key: string, userId: string): boolean {
  return key.startsWith(`${USER_SCOPE}${userId}/`);
}

/**
 * Keys created before per-user scoping (e.g. `covers/<uuid>.jpg`) carry no
 * owner. They are still readable through a signed link so existing covers
 * keep working, but nobody can delete them through this API. Migrate them
 * to `u/<userId>/…` and then remove this allowance.
 */
function isLegacyKey(key: string): boolean {
  return !key.startsWith(USER_SCOPE);
}

// ─── Signed download links ───────────────────────────────────────────

const encoder = new TextEncoder();

async function signingKey(env: Env): Promise<CryptoKey> {
  if (!env.JWT_SECRET) throw new Error('JWT_SECRET is not configured');
  // Domain-separated from the JWT signing use of the same secret.
  return crypto.subtle.importKey(
    'raw',
    encoder.encode(`asset-url:${env.JWT_SECRET}`),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign', 'verify']
  );
}

function toHex(buf: ArrayBuffer): string {
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

function fromHex(hex: string): Uint8Array | null {
  if (hex.length === 0 || hex.length % 2 !== 0 || !/^[0-9a-f]+$/.test(hex)) return null;
  const out = new Uint8Array(hex.length / 2);
  for (let i = 0; i < out.length; i++) out[i] = parseInt(hex.substr(i * 2, 2), 16);
  return out;
}

async function signAsset(env: Env, key: string, exp: number): Promise<string> {
  const sig = await crypto.subtle.sign('HMAC', await signingKey(env), encoder.encode(`${key}\n${exp}`));
  return toHex(sig);
}

async function verifyAssetSig(env: Env, key: string, exp: number, sigHex: string): Promise<boolean> {
  const sig = fromHex(sigHex);
  if (!sig) return false;
  return crypto.subtle.verify(
    'HMAC',
    await signingKey(env),
    sig as ArrayBufferView<ArrayBuffer>,
    encoder.encode(`${key}\n${exp}`)
  );
}

// ─── Auth for the routes that need it ────────────────────────────────

const requireAuth = createMiddleware<{ Bindings: Env; Variables: Variables }>(async (c, next) => {
  const payload = await AuthUtil.authenticateRequest(c.req.header('Authorization'), c.env.JWT_SECRET);
  if (!payload) return c.json({ error: 'Unauthorized' }, 401);
  c.set('userId', payload.sub);
  await next();
});

// ─── Upload ──────────────────────────────────────────────────────────

/**
 * Authenticated upload. The server picks the key, so a client can never
 * write outside its own `u/<userId>/` scope or overwrite another object.
 * Body: raw image bytes with a matching Content-Type.
 * Query: `prefix` (one of ALLOWED_PREFIXES, default `covers`).
 */
assetsRouter.post('/upload', requireAuth, async (c) => {
  const userId = c.get('userId');

  const prefix = c.req.query('prefix') || 'covers';
  if (!ALLOWED_PREFIXES.has(prefix)) {
    return c.json({ error: 'Invalid upload prefix' }, 400);
  }

  const contentType = (c.req.header('Content-Type') || '').split(';')[0].trim().toLowerCase();
  const ext = CONTENT_TYPE_EXT[contentType];
  if (!ext) {
    return c.json({ error: 'Unsupported content type. Use JPEG, PNG, WebP or GIF.' }, 415);
  }

  const declared = Number(c.req.header('Content-Length') || 0);
  if (declared > MAX_UPLOAD_BYTES) {
    return c.json({ error: 'File too large (max 10 MB)' }, 413);
  }

  const body = await c.req.arrayBuffer();
  if (body.byteLength === 0) {
    return c.json({ error: 'No data provided in request body' }, 400);
  }
  if (body.byteLength > MAX_UPLOAD_BYTES) {
    return c.json({ error: 'File too large (max 10 MB)' }, 413);
  }

  const key = `${USER_SCOPE}${userId}/${prefix}/${crypto.randomUUID()}${ext}`;
  await c.env.BUCKET.put(key, body, {
    httpMetadata: { contentType, cacheControl: 'private, max-age=31536000, immutable' },
  });

  return c.json({ key, size: body.byteLength, contentType });
});

// ─── Signed download links ───────────────────────────────────────────

/**
 * Returns a time-limited link for one object. Only the owner can mint a
 * link for a user-scoped key. Query: `key`, optional `expiresIn` seconds.
 */
assetsRouter.get('/presign-download', requireAuth, async (c) => {
  const userId = c.get('userId');
  const key = c.req.query('key') || '';
  if (!isValidKey(key)) return c.json({ error: 'Invalid key' }, 400);
  if (!isOwnKey(key, userId) && !isLegacyKey(key)) {
    return c.json({ error: 'Forbidden' }, 403);
  }

  const requested = Number(c.req.query('expiresIn') || DEFAULT_URL_TTL_SECONDS);
  const ttl = Number.isFinite(requested)
    ? Math.min(Math.max(Math.floor(requested), MIN_URL_TTL_SECONDS), MAX_URL_TTL_SECONDS)
    : DEFAULT_URL_TTL_SECONDS;

  const exp = Math.floor(Date.now() / 1000) + ttl;
  const sig = await signAsset(c.env, key, exp);

  return c.json({
    key,
    expiresAt: exp,
    downloadUrl: `/api/assets/${key}?exp=${exp}&sig=${sig}`,
  });
});

/**
 * Serve an object. Requires a valid, unexpired signature from
 * `/presign-download`, so plain key guessing gets nothing.
 */
assetsRouter.get('/:key{.+}', async (c) => {
  const key = c.req.param('key');
  if (!isValidKey(key)) return c.text('Not found', 404);

  const exp = Number(c.req.query('exp'));
  const sig = c.req.query('sig') || '';
  if (!Number.isInteger(exp) || exp < Math.floor(Date.now() / 1000)) {
    return c.text('Link expired or invalid', 403);
  }
  if (!(await verifyAssetSig(c.env, key, exp, sig))) {
    return c.text('Link expired or invalid', 403);
  }

  const object = await c.env.BUCKET.get(key);
  if (!object) return c.text('Asset not found', 404);

  const ifNoneMatch = c.req.header('If-None-Match');
  if (ifNoneMatch && ifNoneMatch === object.httpEtag) {
    return new Response(null, { status: 304 });
  }

  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set('ETag', object.httpEtag);
  // The link expires, so don't let shared caches keep serving it afterwards.
  headers.set('Cache-Control', 'private, max-age=3600');
  headers.set('X-Content-Type-Options', 'nosniff');
  if (!headers.has('Content-Type')) {
    const lower = key.toLowerCase();
    if (lower.endsWith('.png')) headers.set('Content-Type', 'image/png');
    else if (lower.endsWith('.webp')) headers.set('Content-Type', 'image/webp');
    else if (lower.endsWith('.gif')) headers.set('Content-Type', 'image/gif');
    else headers.set('Content-Type', 'image/jpeg');
  }

  return new Response(object.body, { headers });
});

// ─── Delete ──────────────────────────────────────────────────────────

/** Delete one of the caller's own objects. */
assetsRouter.delete('/:key{.+}', requireAuth, async (c) => {
  const userId = c.get('userId');
  const key = c.req.param('key');
  if (!isValidKey(key)) return c.json({ error: 'Invalid key' }, 400);
  if (!isOwnKey(key, userId)) {
    return c.json({ error: 'Forbidden' }, 403);
  }

  await c.env.BUCKET.delete(key);
  return c.json({ success: true, deletedKey: key });
});
