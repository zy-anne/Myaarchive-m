import { Hono } from 'hono';
import { Env } from '../types';
import { AuthUtil } from '../auth';
import { TursoClient } from '../db';

export const dataRouter = new Hono<{ Bindings: Env }>();

// Require authentication for all /api/data routes
dataRouter.use('*', async (c, next) => {
  const authPayload = await AuthUtil.authenticateRequest(
    c.req.header('Authorization'),
    c.env.JWT_SECRET
  );
  if (!authPayload) {
    return c.json({ error: 'Unauthorized or invalid token' }, 401);
  }
  c.set('userId' as any, authPayload.sub);
  return await next();
});

// ─── Libraries ───────────────────────────────────────────────────────
dataRouter.get('/libraries', async (c) => {
  const userId = c.get('userId' as any) as string;
  const db = new TursoClient(c.env);

  const res = await db.execute(
    'SELECT * FROM libraries WHERE owner_id = ? ORDER BY position, id',
    [userId]
  );
  return c.json({ libraries: res.rows });
});

dataRouter.post('/libraries', async (c) => {
  const userId = c.get('userId' as any) as string;
  const body = await c.req.json<{ name?: string; icon?: string; iconImage?: string }>();
  if (!body.name?.trim()) return c.json({ error: 'Library name required' }, 400);

  const db = new TursoClient(c.env);
  const maxPosRes = await db.execute(
    'SELECT MAX(position) as maxPos FROM libraries WHERE owner_id = ?',
    [userId]
  );
  const nextPos = (maxPosRes.rows[0]?.maxPos ?? -1) + 1;

  const res = await db.execute(
    'INSERT INTO libraries (owner_id, name, icon, icon_image, position) VALUES (?, ?, ?, ?, ?)',
    [userId, body.name.trim(), body.icon || 'grid', body.iconImage || null, nextPos]
  );

  return c.json({ id: res.lastInsertRowid, success: true }, 201);
});

dataRouter.delete('/libraries/:id', async (c) => {
  const userId = c.get('userId' as any) as string;
  const libId = parseInt(c.req.param('id'), 10);
  if (!libId) return c.json({ error: 'Invalid library id' }, 400);

  const db = new TursoClient(c.env);
  // Verify ownership
  const ownerRes = await db.execute(
    'SELECT id FROM libraries WHERE id = ? AND owner_id = ?',
    [libId, userId]
  );
  if (ownerRes.rows.length === 0) {
    return c.json({ error: 'Library not found or unauthorized' }, 404);
  }

  // Cascading delete
  await db.transaction([
    {
      sql: `DELETE FROM series WHERE library_id = ?`,
      args: [libId],
    },
    {
      sql: `DELETE FROM series_groups WHERE library_id = ?`,
      args: [libId],
    },
    {
      sql: `DELETE FROM libraries WHERE id = ? AND owner_id = ?`,
      args: [libId, userId],
    },
  ]);

  return c.json({ success: true });
});

// ─── Tags ────────────────────────────────────────────────────────────
dataRouter.get('/tags', async (c) => {
  const userId = c.get('userId' as any) as string;
  const db = new TursoClient(c.env);

  const res = await db.execute(
    'SELECT * FROM tags WHERE owner_id = ? ORDER BY name COLLATE NOCASE',
    [userId]
  );
  return c.json({ tags: res.rows });
});

// ─── Reading Statuses ───────────────────────────────────────────────
dataRouter.get('/statuses', async (c) => {
  const userId = c.get('userId' as any) as string;
  const db = new TursoClient(c.env);

  const res = await db.execute(
    'SELECT * FROM reading_statuses WHERE owner_id = ? ORDER BY position, id',
    [userId]
  );
  return c.json({ statuses: res.rows });
});

// ─── Settings ────────────────────────────────────────────────────────
dataRouter.get('/settings', async (c) => {
  const userId = c.get('userId' as any) as string;
  const db = new TursoClient(c.env);

  const res = await db.execute('SELECT key, value FROM app_settings WHERE owner_id = ?', [userId]);
  const settings: Record<string, string> = {};
  for (const r of res.rows) {
    if (r.key && r.value !== null) {
      settings[r.key] = String(r.value);
    }
  }
  return c.json({ settings });
});

dataRouter.post('/settings', async (c) => {
  const userId = c.get('userId' as any) as string;
  const body = await c.req.json<{ key?: string; value?: string }>();
  if (!body.key) return c.json({ error: 'Key required' }, 400);

  const db = new TursoClient(c.env);
  await db.execute(
    `INSERT INTO app_settings (owner_id, key, value) VALUES (?, ?, ?)
     ON CONFLICT(owner_id, key) DO UPDATE SET value = excluded.value`,
    [userId, body.key, body.value ?? '']
  );

  return c.json({ success: true });
});
