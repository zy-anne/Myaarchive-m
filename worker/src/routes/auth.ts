import { Hono } from 'hono';
import { Env, UserSession } from '../types';
import { TursoClient } from '../db';
import { AuthUtil } from '../auth';

export const authRouter = new Hono<{ Bindings: Env }>();

const DEFAULT_STATUSES: [string, string][] = [
  ['Reading', '#9B7EDE'],
  ['Finished', '#7FC9A0'],
  ['On Hold', '#E8C15C'],
  ['Planning', '#6FA8DC'],
  ['Dropped', '#DD7A6E'],
];

async function ensureUsersSchema(db: TursoClient): Promise<void> {
  await db.execute(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      username TEXT UNIQUE NOT NULL COLLATE NOCASE,
      password_hash TEXT NOT NULL,
      security_question TEXT,
      security_answer_hash TEXT,
      created_at TEXT DEFAULT (datetime('now'))
    )
  `);
}

// ─── Sign Up ────────────────────────────────────────────────────────
authRouter.post('/signup', async (c) => {
  const db = new TursoClient(c.env);
  const body = await c.req.json<{
    username?: string;
    password?: string;
    securityQuestion?: string;
    securityAnswer?: string;
  }>();

  const username = body.username?.trim();
  const password = body.password;

  if (!username || username.length < 3) {
    return c.json({ error: 'Username must be at least 3 characters' }, 400);
  }
  if (!password || password.length < 4) {
    return c.json({ error: 'Password must be at least 4 characters' }, 400);
  }

  await ensureUsersSchema(db);

  // Check if username taken
  const existing = await db.execute('SELECT id FROM users WHERE username = ?', [username]);
  if (existing.rows.length > 0) {
    return c.json({ error: 'That username is already taken' }, 409);
  }

  const userId = crypto.randomUUID();
  const passwordHash = AuthUtil.hashPassword(password);

  let questionText: string | null = null;
  let answerHash: string | null = null;
  if (body.securityQuestion?.trim() && body.securityAnswer?.trim()) {
    questionText = body.securityQuestion.trim();
    answerHash = AuthUtil.hashPassword(body.securityAnswer.trim().toLowerCase());
  }

  const nowIso = new Date().toISOString();

  // Create user row
  await db.execute(
    `INSERT INTO users (id, username, password_hash, security_question, security_answer_hash, created_at)
     VALUES (?, ?, ?, ?, ?, ?)`,
    [userId, username, passwordHash, questionText, answerHash, nowIso]
  );

  // Seed default library and default statuses for the new user
  try {
    await db.execute(
      `INSERT INTO libraries (owner_id, name, icon, position) VALUES (?, ?, ?, ?)`,
      [userId, 'General', 'grid', 0]
    );

    for (let i = 0; i < DEFAULT_STATUSES.length; i++) {
      const [name, color] = DEFAULT_STATUSES[i];
      await db.execute(
        `INSERT OR IGNORE INTO reading_statuses (owner_id, name, color, position) VALUES (?, ?, ?, ?)`,
        [userId, name, color, i]
      );
    }
  } catch (e) {
    // Non-fatal if schema not created yet; DataLayer will ensure tables
  }

  const user: UserSession = {
    id: userId,
    username,
    securityQuestion: questionText,
    createdAt: nowIso,
  };

  const token = await AuthUtil.signJwt(user, c.env.JWT_SECRET);
  return c.json({ user, token }, 201);
});

// ─── Sign In ────────────────────────────────────────────────────────
authRouter.post('/signin', async (c) => {
  const db = new TursoClient(c.env);
  const body = await c.req.json<{ username?: string; password?: string }>();
  const username = body.username?.trim();
  const password = body.password;

  if (!username || !password) {
    return c.json({ error: 'Username and password are required' }, 400);
  }

  await ensureUsersSchema(db);

  const res = await db.execute('SELECT * FROM users WHERE username = ?', [username]);
  if (res.rows.length === 0) {
    return c.json({ error: 'Invalid username or password' }, 401);
  }

  const row = res.rows[0];
  const isMatch = AuthUtil.comparePassword(password, row.password_hash || '');
  if (!isMatch) {
    return c.json({ error: 'Invalid username or password' }, 401);
  }

  const user: UserSession = {
    id: row.id,
    username: row.username,
    securityQuestion: row.security_question,
    createdAt: row.created_at,
  };

  const token = await AuthUtil.signJwt(user, c.env.JWT_SECRET);
  return c.json({ user, token });
});

// ─── Verify Session / Me ────────────────────────────────────────────
authRouter.get('/me', async (c) => {
  const authPayload = await AuthUtil.authenticateRequest(
    c.req.header('Authorization'),
    c.env.JWT_SECRET
  );
  if (!authPayload) {
    return c.json({ error: 'Unauthorized or token expired' }, 401);
  }

  const db = new TursoClient(c.env);
  const res = await db.execute(
    'SELECT id, username, security_question, created_at FROM users WHERE id = ?',
    [authPayload.sub]
  );
  if (res.rows.length === 0) {
    return c.json({ error: 'User not found' }, 404);
  }

  const row = res.rows[0];
  const user: UserSession = {
    id: row.id,
    username: row.username,
    securityQuestion: row.security_question,
    createdAt: row.created_at,
  };

  return c.json({ user });
});

// ─── Change Password ────────────────────────────────────────────────
authRouter.post('/change-password', async (c) => {
  const authPayload = await AuthUtil.authenticateRequest(
    c.req.header('Authorization'),
    c.env.JWT_SECRET
  );
  if (!authPayload) {
    return c.json({ error: 'Unauthorized' }, 401);
  }

  const body = await c.req.json<{ currentPassword?: string; newPassword?: string }>();
  if (!body.currentPassword || !body.newPassword || body.newPassword.length < 4) {
    return c.json({ error: 'New password must be at least 4 characters' }, 400);
  }

  const db = new TursoClient(c.env);
  const res = await db.execute('SELECT password_hash FROM users WHERE id = ?', [authPayload.sub]);
  if (res.rows.length === 0) {
    return c.json({ error: 'User not found' }, 404);
  }

  const currentHash = res.rows[0].password_hash || '';
  if (!AuthUtil.comparePassword(body.currentPassword, currentHash)) {
    return c.json({ error: 'Current password is incorrect' }, 403);
  }

  const newHash = AuthUtil.hashPassword(body.newPassword);
  await db.execute('UPDATE users SET password_hash = ? WHERE id = ?', [newHash, authPayload.sub]);

  return c.json({ success: true });
});

// ─── Forgot Password / Security Question ─────────────────────────────
authRouter.get('/security-question', async (c) => {
  const username = c.req.query('username')?.trim();
  if (!username) {
    return c.json({ error: 'Username required' }, 400);
  }

  const db = new TursoClient(c.env);
  await ensureUsersSchema(db);

  const res = await db.execute(
    'SELECT security_question, security_answer_hash FROM users WHERE username = ?',
    [username]
  );
  if (res.rows.length === 0) {
    return c.json({ error: 'No account found with that username' }, 404);
  }

  const row = res.rows[0];
  if (!row.security_question || !row.security_answer_hash) {
    return c.json({ error: 'No recovery question set up for this account' }, 404);
  }

  return c.json({ securityQuestion: row.security_question });
});

// ─── Reset Password With Security Answer ─────────────────────────────
authRouter.post('/reset-password', async (c) => {
  const body = await c.req.json<{
    username?: string;
    securityAnswer?: string;
    newPassword?: string;
  }>();

  const username = body.username?.trim();
  const answer = body.securityAnswer?.trim();
  const newPassword = body.newPassword;

  if (!username || !answer || !newPassword || newPassword.length < 4) {
    return c.json({ error: 'Invalid reset parameters' }, 400);
  }

  const db = new TursoClient(c.env);
  const res = await db.execute(
    'SELECT id, security_answer_hash FROM users WHERE username = ?',
    [username]
  );
  if (res.rows.length === 0) {
    return c.json({ error: 'No account found with that username' }, 404);
  }

  const row = res.rows[0];
  const answerHash = row.security_answer_hash || '';
  if (!answerHash || !AuthUtil.comparePassword(answer.toLowerCase(), answerHash)) {
    return c.json({ error: "That answer doesn't match our records" }, 403);
  }

  const newHash = AuthUtil.hashPassword(newPassword);
  await db.execute('UPDATE users SET password_hash = ? WHERE id = ?', [newHash, row.id]);

  return c.json({ success: true });
});

// ─── Delete Account (Verify Password First + Atomic Cascade) ────────
authRouter.post('/delete-account', async (c) => {
  const authPayload = await AuthUtil.authenticateRequest(
    c.req.header('Authorization'),
    c.env.JWT_SECRET
  );
  if (!authPayload) {
    return c.json({ error: 'Unauthorized' }, 401);
  }

  const body = await c.req.json<{ password?: string }>();
  if (!body.password) {
    return c.json({ error: 'Password required to delete account' }, 400);
  }

  const db = new TursoClient(c.env);
  const res = await db.execute('SELECT password_hash FROM users WHERE id = ?', [authPayload.sub]);
  if (res.rows.length === 0) {
    return c.json({ error: 'User not found' }, 404);
  }

  if (!AuthUtil.comparePassword(body.password, res.rows[0].password_hash || '')) {
    return c.json({ error: 'Password is incorrect' }, 403);
  }

  const userId = authPayload.sub;

  // 1. Gather R2 object keys to sweep
  const assetKeysToDelete: string[] = [];
  try {
    const coversRes = await db.execute(
      `SELECT cover_image_path FROM series
       WHERE library_id IN (SELECT id FROM libraries WHERE owner_id = ?)
         AND cover_image_path IS NOT NULL`,
      [userId]
    );
    for (const row of coversRes.rows) {
      if (row.cover_image_path) assetKeysToDelete.push(String(row.cover_image_path));
    }

    const volRes = await db.execute(
      `SELECT cover_image_path FROM volumes
       WHERE series_id IN (
         SELECT id FROM series WHERE library_id IN (SELECT id FROM libraries WHERE owner_id = ?)
       ) AND cover_image_path IS NOT NULL`,
      [userId]
    );
    for (const row of volRes.rows) {
      if (row.cover_image_path) assetKeysToDelete.push(String(row.cover_image_path));
    }

    const galleryRes = await db.execute(
      `SELECT image_path FROM gallery_images
       WHERE series_id IN (
         SELECT id FROM series WHERE library_id IN (SELECT id FROM libraries WHERE owner_id = ?)
       ) AND image_path IS NOT NULL`,
      [userId]
    );
    for (const row of galleryRes.rows) {
      if (row.image_path) assetKeysToDelete.push(String(row.image_path));
    }
  } catch {
    // Non-fatal if query fails
  }

  // 2. Cascade delete all owned DB records in atomic transaction
  await db.transaction([
    {
      sql: `DELETE FROM relationships WHERE from_character_id IN (
              SELECT id FROM characters WHERE series_id IN (
                SELECT id FROM series WHERE library_id IN (SELECT id FROM libraries WHERE owner_id = ?)
              )
            ) OR to_character_id IN (
              SELECT id FROM characters WHERE series_id IN (
                SELECT id FROM series WHERE library_id IN (SELECT id FROM libraries WHERE owner_id = ?)
              )
            )`,
      args: [userId, userId],
    },
    {
      sql: `DELETE FROM characters WHERE series_id IN (
              SELECT id FROM series WHERE library_id IN (SELECT id FROM libraries WHERE owner_id = ?)
            )`,
      args: [userId],
    },
    {
      sql: `DELETE FROM volumes WHERE series_id IN (
              SELECT id FROM series WHERE library_id IN (SELECT id FROM libraries WHERE owner_id = ?)
            )`,
      args: [userId],
    },
    {
      sql: `DELETE FROM series_tags WHERE series_id IN (
              SELECT id FROM series WHERE library_id IN (SELECT id FROM libraries WHERE owner_id = ?)
            )`,
      args: [userId],
    },
    {
      sql: `DELETE FROM series_genres WHERE series_id IN (
              SELECT id FROM series WHERE library_id IN (SELECT id FROM libraries WHERE owner_id = ?)
            )`,
      args: [userId],
    },
    {
      sql: `DELETE FROM series_content_warnings WHERE series_id IN (
              SELECT id FROM series WHERE library_id IN (SELECT id FROM libraries WHERE owner_id = ?)
            )`,
      args: [userId],
    },
    {
      sql: `DELETE FROM gallery_images WHERE series_id IN (
              SELECT id FROM series WHERE library_id IN (SELECT id FROM libraries WHERE owner_id = ?)
            )`,
      args: [userId],
    },
    {
      sql: `DELETE FROM link_attachments WHERE series_id IN (
              SELECT id FROM series WHERE library_id IN (SELECT id FROM libraries WHERE owner_id = ?)
            )`,
      args: [userId],
    },
    {
      sql: `DELETE FROM attachments WHERE series_id IN (
              SELECT id FROM series WHERE library_id IN (SELECT id FROM libraries WHERE owner_id = ?)
            )`,
      args: [userId],
    },
    {
      sql: `DELETE FROM glossary_terms WHERE series_id IN (
              SELECT id FROM series WHERE library_id IN (SELECT id FROM libraries WHERE owner_id = ?)
            )`,
      args: [userId],
    },
    {
      sql: `DELETE FROM series_group_items WHERE group_id IN (
              SELECT id FROM series_groups WHERE library_id IN (SELECT id FROM libraries WHERE owner_id = ?)
            )`,
      args: [userId],
    },
    {
      sql: `DELETE FROM series_groups WHERE library_id IN (SELECT id FROM libraries WHERE owner_id = ?)`,
      args: [userId],
    },
    {
      sql: `DELETE FROM series WHERE library_id IN (SELECT id FROM libraries WHERE owner_id = ?)`,
      args: [userId],
    },
    {
      sql: `DELETE FROM libraries WHERE owner_id = ?`,
      args: [userId],
    },
    {
      sql: `DELETE FROM tags WHERE owner_id = ?`,
      args: [userId],
    },
    {
      sql: `DELETE FROM content_warnings WHERE owner_id = ?`,
      args: [userId],
    },
    {
      sql: `DELETE FROM reading_statuses WHERE owner_id = ?`,
      args: [userId],
    },
    {
      sql: `DELETE FROM app_settings WHERE owner_id = ?`,
      args: [userId],
    },
    {
      sql: `DELETE FROM users WHERE id = ?`,
      args: [userId],
    },
  ]);

  // 3. Delete R2 assets from bucket
  if (c.env.BUCKET && assetKeysToDelete.length > 0) {
    for (const key of assetKeysToDelete) {
      try {
        await c.env.BUCKET.delete(key);
      } catch {
        // Continue sweeping others
      }
    }
  }

  return c.json({ success: true, message: 'Account and all data deleted successfully' });
});
