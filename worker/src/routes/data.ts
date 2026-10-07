import { Hono } from 'hono';
import { Env } from '../types';
import { AuthUtil } from '../auth';
import { TursoClient } from '../db';

type Variables = { userId: string };

export const dataRouter = new Hono<{ Bindings: Env; Variables: Variables }>();

/** Settings keys clients are allowed to write. */
const ALLOWED_SETTING_KEYS = new Set([
  'themeMode',
  'colorPaletteId',
  'showNsfwContent',
  'defaultStartTab',
  'autoOpenDetailAfterAdd',
  'annualReadingGoal',
]);

const MAX_SETTING_VALUE_LENGTH = 200;

/** Strict positive-integer parse: rejects '', '12abc', '1.5', '-3', '0'. */
function parseId(raw: string | undefined): number | null {
  if (!raw || !/^\d+$/.test(raw)) return null;
  const n = Number(raw);
  return Number.isSafeInteger(n) && n > 0 ? n : null;
}

// Require authentication for all /api/data routes
dataRouter.use('*', async (c, next) => {
  const authPayload = await AuthUtil.authenticateRequest(
    c.req.header('Authorization'),
    c.env.JWT_SECRET
  );
  if (!authPayload) {
    return c.json({ error: 'Unauthorized or invalid token' }, 401);
  }
  c.set('userId', authPayload.sub);
  await next();
});

// ─── Libraries ───────────────────────────────────────────────────────
dataRouter.get('/libraries', async (c) => {
  const userId = c.get('userId');
  const db = new TursoClient(c.env);

  const res = await db.execute(
    'SELECT * FROM libraries WHERE owner_id = ? ORDER BY position, id',
    [userId]
  );
  return c.json({ libraries: res.rows });
});

dataRouter.post('/libraries', async (c) => {
  const userId = c.get('userId');

  let body: { name?: string; icon?: string; iconImage?: string };
  try {
    body = await c.req.json();
  } catch {
    return c.json({ error: 'Invalid JSON body' }, 400);
  }
  const name = typeof body.name === 'string' ? body.name.trim() : '';
  if (!name) return c.json({ error: 'Library name required' }, 400);

  const db = new TursoClient(c.env);
  const maxPosRes = await db.execute(
    'SELECT MAX(position) as maxPos FROM libraries WHERE owner_id = ?',
    [userId]
  );
  // MAX() is NULL when the user has no libraries yet. TursoClient decodes
  // integers to JS numbers, but wrap in Number() so a loosely typed row
  // can never turn `+ 1` into string concatenation.
  const nextPos = Number(maxPosRes.rows[0]?.maxPos ?? -1) + 1;

  const res = await db.execute(
    'INSERT INTO libraries (owner_id, name, icon, icon_image, position) VALUES (?, ?, ?, ?, ?)',
    [userId, name, body.icon || 'grid', body.iconImage || null, nextPos]
  );

  return c.json({ id: res.lastInsertRowid, success: true }, 201);
});

dataRouter.delete('/libraries/:id', async (c) => {
  const userId = c.get('userId');
  const libId = parseId(c.req.param('id'));
  if (libId === null) return c.json({ error: 'Invalid library id' }, 400);

  const db = new TursoClient(c.env);
  // Verify ownership
  const ownerRes = await db.execute(
    'SELECT id FROM libraries WHERE id = ? AND owner_id = ?',
    [libId, userId]
  );
  if (ownerRes.rows.length === 0) {
    return c.json({ error: 'Library not found or unauthorized' }, 404);
  }

  const seriesInLib = 'SELECT id FROM series WHERE library_id = ?';
  const charsInLib = `SELECT id FROM characters WHERE series_id IN (${seriesInLib})`;

  // Cascading delete: children first, then series, groups, and the library.
  await db.transaction([
    {
      sql: `DELETE FROM relationships
            WHERE from_character_id IN (${charsInLib})
               OR to_character_id IN (${charsInLib})`,
      args: [libId, libId],
    },
    {
      sql: `DELETE FROM characters WHERE series_id IN (${seriesInLib})`,
      args: [libId],
    },
    {
      sql: `DELETE FROM volumes WHERE series_id IN (${seriesInLib})`,
      args: [libId],
    },
    {
      sql: `DELETE FROM series_tags WHERE series_id IN (${seriesInLib})`,
      args: [libId],
    },
    {
      sql: `DELETE FROM series_genres WHERE series_id IN (${seriesInLib})`,
      args: [libId],
    },
    {
      sql: `DELETE FROM series_content_warnings WHERE series_id IN (${seriesInLib})`,
      args: [libId],
    },
    {
      sql: `DELETE FROM gallery_images WHERE series_id IN (${seriesInLib})`,
      args: [libId],
    },
    {
      sql: `DELETE FROM link_attachments WHERE series_id IN (${seriesInLib})`,
      args: [libId],
    },
    {
      sql: `DELETE FROM attachments WHERE series_id IN (${seriesInLib})`,
      args: [libId],
    },
    {
      sql: `DELETE FROM glossary_terms WHERE series_id IN (${seriesInLib})`,
      args: [libId],
    },
    {
      // Membership rows for this library's series (a series can still be
      // linked to a group in another library after a transfer) and for
      // this library's own groups.
      sql: `DELETE FROM series_group_items
            WHERE series_id IN (${seriesInLib})
               OR group_id IN (SELECT id FROM series_groups WHERE library_id = ?)`,
      args: [libId, libId],
    },
    {
      sql: `DELETE FROM series_groups WHERE library_id = ?`,
      args: [libId],
    },
    {
      sql: `DELETE FROM series WHERE library_id = ?`,
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
  const userId = c.get('userId');
  const db = new TursoClient(c.env);

  const res = await db.execute(
    'SELECT * FROM tags WHERE owner_id = ? ORDER BY name COLLATE NOCASE',
    [userId]
  );
  return c.json({ tags: res.rows });
});

// ─── Reading Statuses ───────────────────────────────────────────────
dataRouter.get('/statuses', async (c) => {
  const userId = c.get('userId');
  const db = new TursoClient(c.env);

  const res = await db.execute(
    'SELECT * FROM reading_statuses WHERE owner_id = ? ORDER BY position, id',
    [userId]
  );
  return c.json({ statuses: res.rows });
});

// ─── Settings ────────────────────────────────────────────────────────
dataRouter.get('/settings', async (c) => {
  const userId = c.get('userId');
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
  const userId = c.get('userId');

  let body: { key?: string; value?: string };
  try {
    body = await c.req.json();
  } catch {
    return c.json({ error: 'Invalid JSON body' }, 400);
  }

  if (typeof body.key !== 'string' || !body.key) {
    return c.json({ error: 'Key required' }, 400);
  }
  if (!ALLOWED_SETTING_KEYS.has(body.key)) {
    return c.json({ error: `Unknown setting key: ${body.key}` }, 400);
  }

  const value = String(body.value ?? '');
  if (value.length > MAX_SETTING_VALUE_LENGTH) {
    return c.json({ error: 'Setting value too long' }, 400);
  }

  const db = new TursoClient(c.env);
  await db.execute(
    `INSERT INTO app_settings (owner_id, key, value) VALUES (?, ?, ?)
     ON CONFLICT(owner_id, key) DO UPDATE SET value = excluded.value`,
    [userId, body.key, value]
  );

  return c.json({ success: true });
});