import { Hono } from 'hono';
import { Env } from '../types';
import { AuthUtil } from '../auth';

export const assetsRouter = new Hono<{ Bindings: Env }>();

/**
 * Direct file upload to R2 through Cloudflare Worker.
 * Accepts binary body or multipart form data with image.
 * Requires Bearer JWT.
 */
assetsRouter.post('/upload', async (c) => {
  const authPayload = await AuthUtil.authenticateRequest(
    c.req.header('Authorization'),
    c.env.JWT_SECRET
  );
  if (!authPayload) {
    return c.json({ error: 'Unauthorized' }, 401);
  }

  const prefix = c.req.query('prefix') || 'covers';
  const filename = c.req.query('filename') || '';
  let ext = '';
  const dotIdx = filename.lastIndexOf('.');
  if (dotIdx >= 0) ext = filename.substring(dotIdx).toLowerCase();
  if (!ext) {
    const ct = c.req.header('Content-Type') || '';
    if (ct.includes('png')) ext = '.png';
    else if (ct.includes('webp')) ext = '.webp';
    else ext = '.jpg';
  }

  const key = `${prefix}/${crypto.randomUUID()}${ext}`;
  const contentType =
    c.req.header('Content-Type') ||
    (ext === '.png' ? 'image/png' : ext === '.webp' ? 'image/webp' : 'image/jpeg');

  const arrayBuffer = await c.req.arrayBuffer();
  if (!arrayBuffer || arrayBuffer.byteLength === 0) {
    return c.json({ error: 'No data provided in request body' }, 400);
  }

  await c.env.BUCKET.put(key, arrayBuffer, {
    httpMetadata: {
      contentType,
      cacheControl: 'public, max-age=31536000, immutable',
    },
  });

  return c.json({
    key,
    url: `/api/assets/${key}`,
    size: arrayBuffer.byteLength,
    contentType,
  });
});

/**
 * Presigned upload / download metadata helper.
 */
assetsRouter.get('/presign-download', async (c) => {
  const key = c.req.query('key');
  if (!key) return c.json({ error: 'Key required' }, 400);

  const url = `/api/assets/${key}`;
  return c.json({ key, downloadUrl: url });
});

/**
 * Serve asset directly from Cloudflare R2 bucket with edge caching.
 */
assetsRouter.get('/:key{.+}', async (c) => {
  const key = c.req.param('key');
  if (!key) return c.text('Not found', 404);

  const object = await c.env.BUCKET.get(key);
  if (!object) {
    return c.text('Asset not found', 404);
  }

  // Handle If-None-Match 304
  const ifNoneMatch = c.req.header('If-None-Match');
  if (ifNoneMatch && ifNoneMatch === object.httpEtag) {
    return new Response(null, { status: 304 });
  }

  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set('ETag', object.httpEtag);
  headers.set('Cache-Control', 'public, max-age=31536000, immutable');
  if (!headers.has('Content-Type')) {
    const lower = key.toLowerCase();
    if (lower.endsWith('.png')) headers.set('Content-Type', 'image/png');
    else if (lower.endsWith('.webp')) headers.set('Content-Type', 'image/webp');
    else headers.set('Content-Type', 'image/jpeg');
  }

  return new Response(object.body, { headers });
});

/**
 * Delete asset from R2. Requires Bearer JWT.
 */
assetsRouter.delete('/:key{.+}', async (c) => {
  const authPayload = await AuthUtil.authenticateRequest(
    c.req.header('Authorization'),
    c.env.JWT_SECRET
  );
  if (!authPayload) {
    return c.json({ error: 'Unauthorized' }, 401);
  }

  const key = c.req.param('key');
  if (!key) return c.json({ error: 'Key required' }, 400);

  await c.env.BUCKET.delete(key);
  return c.json({ success: true, deletedKey: key });
});
