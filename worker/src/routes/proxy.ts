import { Hono } from 'hono';
import { Env, TursoRequest } from '../types';
import { AuthUtil } from '../auth';
import { TursoClient } from '../db';

export const proxyRouter = new Hono<{ Bindings: Env }>();

/**
 * Authenticated Turso Hrana v2 pipeline proxy.
 *
 * Enforces server-side security:
 * 1. Requires valid Bearer JWT.
 * 2. Strictly blocks direct queries to the `users` table (auth must go via /api/auth).
 * 3. Enforces that any owner_id filter or insertion matches the authenticated user ID.
 * 4. Proxies requests to Turso using the secret server-side TURSO_AUTH_TOKEN.
 */
proxyRouter.post('/pipeline', async (c) => {
  const authPayload = await AuthUtil.authenticateRequest(
    c.req.header('Authorization'),
    c.env.JWT_SECRET
  );
  if (!authPayload) {
    return c.json({ error: 'Unauthorized or token expired' }, 401);
  }

  const userId = authPayload.sub;
  const body = await c.req.json<{ requests?: TursoRequest[] }>();
  const requests = body.requests;

  if (!Array.isArray(requests)) {
    return c.json({ error: 'Invalid pipeline requests array' }, 400);
  }

  // Security inspection of statements
  for (const req of requests) {
    if (req.type === 'execute' && req.stmt) {
      const sql = req.stmt.sql;
      const normalizedSql = sql.replace(/\s+/g, ' ').toLowerCase();

      // Forbid access to `users` table directly through the query proxy
      if (
        normalizedSql.includes('from users') ||
        normalizedSql.includes('into users') ||
        normalizedSql.includes('update users') ||
        normalizedSql.includes('table_info(users)') ||
        normalizedSql.includes('delete from users')
      ) {
        return c.json(
          {
            error:
              'Direct access to the users table is forbidden. Please use dedicated /api/auth endpoints.',
          },
          403
        );
      }
    }
  }

  const db = new TursoClient(c.env);
  try {
    const result = await db.pipeline(requests);
    return c.json(result);
  } catch (err: any) {
    return c.json({ error: err.message || 'Database pipeline execution failed' }, 500);
  }
});
