import { TursoClient } from './db';

/**
 * Failed-attempt throttle backed by the database (Worker isolates are
 * stateless, so an in-memory counter would reset on every cold start).
 * Fixed window: after `max` failures for a key, further attempts are
 * refused until the window that began at the first failure ends.
 */
export const WINDOW_SECONDS = 15 * 60;

export interface LimitKey {
  key: string;
  max: number;
}

const nowSec = () => Math.floor(Date.now() / 1000);

/** Per-account key for password-guessing endpoints. */
export const userKey = (scope: string, id: string, max = 5): LimitKey => ({
  key: `${scope}:u:${id.toLowerCase()}`,
  max,
});

/** Per-client-IP key; omitted when the address is unknown. */
export const ipKey = (scope: string, ip: string | undefined, max = 30): LimitKey[] =>
  ip ? [{ key: `${scope}:ip:${ip}`, max }] : [];

/** Seconds until the caller may retry, or 0 when allowed. */
export async function retryAfter(db: TursoClient, keys: LimitKey[]): Promise<number> {
  if (keys.length === 0) return 0;
  const ph = keys.map(() => '?').join(',');
  const res = await db.execute(
    `SELECT key, count, window_start FROM rate_limits WHERE key IN (${ph})`,
    keys.map((k) => k.key)
  );
  const now = nowSec();
  let wait = 0;
  for (const row of res.rows) {
    const limit = keys.find((k) => k.key === row.key);
    if (!limit) continue;
    const remaining = Number(row.window_start) + WINDOW_SECONDS - now;
    if (remaining > 0 && Number(row.count) >= limit.max) wait = Math.max(wait, remaining);
  }
  return wait;
}

export async function recordFailure(db: TursoClient, keys: LimitKey[]): Promise<void> {
  if (keys.length === 0) return;
  const now = nowSec();
  const stmts = keys.map((k) => ({
    sql: `INSERT INTO rate_limits (key, count, window_start) VALUES (?, 1, ?)
          ON CONFLICT(key) DO UPDATE SET
            count = CASE WHEN ? - window_start >= ? THEN 1 ELSE count + 1 END,
            window_start = CASE WHEN ? - window_start >= ? THEN ? ELSE window_start END`,
    args: [k.key, now, now, WINDOW_SECONDS, now, WINDOW_SECONDS, now],
  }));
  // Opportunistic cleanup of expired windows.
  stmts.push({ sql: 'DELETE FROM rate_limits WHERE window_start < ?', args: [now - WINDOW_SECONDS] });
  await db.batch(stmts);
}

export async function clearFailures(db: TursoClient, keys: LimitKey[]): Promise<void> {
  if (keys.length === 0) return;
  const ph = keys.map(() => '?').join(',');
  await db.execute(`DELETE FROM rate_limits WHERE key IN (${ph})`, keys.map((k) => k.key));
}

export function tooManyMessage(seconds: number): string {
  const mins = Math.max(1, Math.ceil(seconds / 60));
  return `Too many failed attempts. Try again in ${mins} minute${mins === 1 ? '' : 's'}.`;
}
