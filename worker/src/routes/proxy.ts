import { Hono } from 'hono';
import { Env, TursoRequest } from '../types';
import { AuthUtil } from '../auth';
import { TursoClient } from '../db';

export const proxyRouter = new Hono<{ Bindings: Env }>();

/**
 * Authenticated Turso Hrana v2 pipeline proxy (TRANSITIONAL).
 *
 * What this DOES enforce:
 *  1. A valid Bearer JWT is required; the Turso token never leaves the Worker.
 *  2. Only `execute` and `close` requests, with sane size limits.
 *  3. The `users` table is unreachable, however it is quoted, aliased or
 *     hidden behind comments or string tricks.
 *  4. Schema-escape and destructive statements are rejected (ATTACH, DROP,
 *     VACUUM, load_extension, sqlite_* tables, PRAGMAs other than table_info).
 *
 * What this does NOT enforce: per-user row ownership. Rows in `series`,
 * `volumes`, `characters` and so on are tied to a user only through
 * `libraries.owner_id`, and arbitrary client SQL cannot be rewritten safely.
 * Any signed-in user can still read or modify another user's rows through
 * this endpoint. Closing that gap means moving each query behind a dedicated
 * owner-checked route (see `/api/data`) and then deleting this proxy.
 */

const MAX_REQUESTS = 200;
const MAX_SQL_LENGTH = 20_000;
const MAX_ARGS = 500;

/**
 * Lowercase the SQL and strip everything that could hide or fake a keyword:
 * comments, string literals, and identifier quoting.
 */
function normalizeSql(sql: string): string {
  return sql
    .replace(/\/\*[\s\S]*?\*\//g, ' ') // block comments
    .replace(/--[^\n]*/g, ' ') // line comments
    .replace(/'(?:[^']|'')*'/g, "''") // string literals
    .replace(/[`"\[\]]/g, ' ') // identifier quoting: "users", `users`, [users]
    .replace(/\s+/g, ' ')
    .trim()
    .toLowerCase();
}

/** Returns a reason string if the statement must be rejected, else null. */
export function rejectReason(sql: string): string | null {
  const s = normalizeSql(sql);

  if (/\busers\b/.test(s)) {
    return 'Direct access to the users table is forbidden. Use the /api/auth endpoints.';
  }
  if (/\bsqlite_\w*/.test(s)) {
    return 'Access to SQLite internal tables is forbidden.';
  }
  if (/\b(attach|detach|vacuum|load_extension|drop|truncate)\b/.test(s)) {
    return 'This statement type is not allowed.';
  }
  if (/\bpragma\b/.test(s) && !/^pragma table_info\s*\(\s*\w+\s*\)$/.test(s)) {
    return 'Only PRAGMA table_info is allowed.';
  }
  // Hrana executes one statement per request; a second one after a `;` is
  // either a mistake or an attempt to smuggle something past these checks.
  if (/;\s*\S/.test(s)) {
    return 'Multiple statements per request are not allowed.';
  }
  return null;
}

proxyRouter.post('/pipeline', async (c) => {
  const authPayload = await AuthUtil.authenticateRequest(
    c.req.header('Authorization'),
    c.env.JWT_SECRET
  );
  if (!authPayload) {
    return c.json({ error: 'Unauthorized or token expired' }, 401);
  }

  let body: { requests?: TursoRequest[] };
  try {
    body = await c.req.json();
  } catch {
    return c.json({ error: 'Invalid JSON body' }, 400);
  }

  const requests = body.requests;
  if (!Array.isArray(requests) || requests.length === 0 || requests.length > MAX_REQUESTS) {
    return c.json({ error: 'Invalid pipeline requests array' }, 400);
  }

  for (const req of requests) {
    if (!req || (req.type !== 'execute' && req.type !== 'close')) {
      return c.json({ error: 'Only execute and close requests are allowed' }, 400);
    }
    if (req.type === 'close') continue;

    const sql = req.stmt?.sql;
    if (typeof sql !== 'string' || sql.length === 0 || sql.length > MAX_SQL_LENGTH) {
      return c.json({ error: 'Invalid SQL statement' }, 400);
    }
    if (req.stmt?.args && (!Array.isArray(req.stmt.args) || req.stmt.args.length > MAX_ARGS)) {
      return c.json({ error: 'Invalid statement arguments' }, 400);
    }

    const reason = rejectReason(sql);
    if (reason) return c.json({ error: reason }, 403);
  }

  const db = new TursoClient(c.env);
  try {
    const result = await db.pipeline(requests);
    return c.json(result);
  } catch (err: any) {
    console.error('Turso pipeline error:', err);
    return c.json({ error: 'Database pipeline execution failed' }, 500);
  }
});
