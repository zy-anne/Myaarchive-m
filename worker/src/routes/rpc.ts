import { Hono } from 'hono';
import { Env } from '../types';
import { AuthUtil } from '../auth';
import { TursoClient } from '../db';
import { ensureSchema } from '../schema';

/**
 * Owner-checked data API.
 *
 * Every operation receives the user id from the verified JWT, never from the
 * request body, and proves ownership of every row it touches before reading or
 * writing it. Ownership chain:
 *
 *   libraries.owner_id  ->  series.library_id  ->  volumes / characters /
 *   gallery / links / attachments / glossary (series_id)  ->  relationships
 *   (character ids)
 *
 * This replaces the arbitrary-SQL proxy at /api/db/pipeline, which cannot
 * enforce row ownership.
 */

type Variables = { userId: string };
type Db = TursoClient;
type Args = Record<string, any>;
type Handler = (c: Ctx) => Promise<unknown>;

interface Ctx {
  db: Db;
  env: Env;
  userId: string;
  a: Args;
}

class HttpError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

const bad = (m: string) => new HttpError(400, m);
const notFound = (m = 'Not found') => new HttpError(404, m);

// ─── Validation helpers ──────────────────────────────────────────────

function int(v: unknown, name: string): number {
  const n = typeof v === 'string' && /^\d+$/.test(v) ? Number(v) : v;
  if (typeof n !== 'number' || !Number.isSafeInteger(n) || n <= 0) {
    throw bad(`Invalid ${name}`);
  }
  return n;
}

function optInt(v: unknown): number | null {
  if (v === null || v === undefined || v === '') return null;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

function str(v: unknown, name: string, max = 20_000): string {
  if (typeof v !== 'string') throw bad(`Invalid ${name}`);
  if (v.length > max) throw bad(`${name} too long`);
  return v;
}

function optStr(v: unknown, max = 20_000): string | null {
  if (v === null || v === undefined) return null;
  const s = String(v);
  if (s.length > max) throw bad('Value too long');
  return s;
}

function strList(v: unknown, max = 100): string[] {
  if (v === undefined || v === null) return [];
  if (!Array.isArray(v) || v.length > max) throw bad('Invalid list');
  return v.map((x) => String(x).trim()).filter((x) => x.length > 0 && x.length <= 200);
}

function intList(v: unknown, max = 5000): number[] {
  if (!Array.isArray(v) || v.length > max) throw bad('Invalid id list');
  return v.map((x) => int(x, 'id'));
}

// ─── Ownership proofs ────────────────────────────────────────────────

async function requireLibrary(ctx: Ctx, id: number): Promise<void> {
  const r = await ctx.db.execute(
    'SELECT id FROM libraries WHERE id = ? AND owner_id = ?',
    [id, ctx.userId]
  );
  if (r.rows.length === 0) throw notFound('Library not found');
}

async function requireSeries(ctx: Ctx, id: number): Promise<void> {
  const r = await ctx.db.execute(
    `SELECT s.id FROM series s JOIN libraries l ON l.id = s.library_id
     WHERE s.id = ? AND l.owner_id = ?`,
    [id, ctx.userId]
  );
  if (r.rows.length === 0) throw notFound('Title not found');
}

async function requireCharacter(ctx: Ctx, id: number): Promise<number> {
  const r = await ctx.db.execute(
    `SELECT c.series_id FROM characters c
     JOIN series s ON s.id = c.series_id
     JOIN libraries l ON l.id = s.library_id
     WHERE c.id = ? AND l.owner_id = ?`,
    [id, ctx.userId]
  );
  if (r.rows.length === 0) throw notFound('Character not found');
  return r.rows[0].series_id as number;
}

async function requireGroup(ctx: Ctx, id: number): Promise<void> {
  const r = await ctx.db.execute(
    `SELECT g.id FROM series_groups g JOIN libraries l ON l.id = g.library_id
     WHERE g.id = ? AND l.owner_id = ?`,
    [id, ctx.userId]
  );
  if (r.rows.length === 0) throw notFound('Group not found');
}

/** SQL fragment: series ids owned by the caller. Args: [userId]. */
const OWNED_SERIES = `SELECT s.id FROM series s JOIN libraries l ON l.id = s.library_id WHERE l.owner_id = ?`;

// ─── R2 sweep (Phase 3: no orphaned objects, no shared-key deletes) ──

const ASSET_COLUMNS: Array<[string, string]> = [
  ['series', 'cover_image_path'],
  ['volumes', 'cover_image_path'],
  ['characters', 'profile_image_path'],
  ['gallery_images', 'image_path'],
  ['attachments', 'file_path'],
  ['libraries', 'icon_image'],
];

/**
 * Deletes each candidate key from R2 only if it lives under the caller's own
 * `u/<userId>/` scope AND no row anywhere still references it. A title copy
 * shares keys with its original, so this is the reference count.
 */
async function sweepAssets(ctx: Ctx, candidates: Array<string | null | undefined>): Promise<void> {
  const prefix = `u/${ctx.userId}/`;
  const keys = [...new Set(candidates.filter((k): k is string => !!k && k.startsWith(prefix)))];
  if (keys.length === 0) return;
  const checks = ASSET_COLUMNS.map(([t, col]) => `SELECT 1 FROM ${t} WHERE ${col} = ?`);
  const sql = `SELECT 1 AS x FROM (${checks.join(' UNION ALL ')}) LIMIT 1`;
  // One database round trip for all keys, and one R2 call per 1000 deletes,
  // so removing many titles at once stays within Worker subrequest limits.
  const results = await ctx.db.batch(keys.map((k) => ({ sql, args: ASSET_COLUMNS.map(() => k) })));
  const unused = keys.filter((_, i) => results[i].rows.length === 0);
  for (let i = 0; i < unused.length; i += 1000) {
    try {
      await ctx.env.BUCKET.delete(unused.slice(i, i + 1000));
    } catch (err) {
      console.error('R2 sweep failed', err);
    }
  }
}

async function assetKeysForSeries(ctx: Ctx, whereSeries: string, args: any[]): Promise<string[]> {
  const q = (sql: string) => ctx.db.execute(sql, args);
  const [s, v, c, g, at] = await Promise.all([
    q(`SELECT cover_image_path AS k FROM series WHERE id IN (${whereSeries})`),
    q(`SELECT cover_image_path AS k FROM volumes WHERE series_id IN (${whereSeries})`),
    q(`SELECT profile_image_path AS k FROM characters WHERE series_id IN (${whereSeries})`),
    q(`SELECT image_path AS k FROM gallery_images WHERE series_id IN (${whereSeries})`),
    q(`SELECT file_path AS k FROM attachments WHERE series_id IN (${whereSeries})`),
  ]);
  return [s, v, c, g, at].flatMap((r) => r.rows.map((x) => x.k as string)).filter(Boolean);
}

// ─── Series cascade ──────────────────────────────────────────────────

/** Statements that remove every child of the series ids selected by `sel`. */
function seriesChildDeletes(sel: string, args: any[]) {
  const chars = `SELECT id FROM characters WHERE series_id IN (${sel})`;
  return [
    {
      sql: `DELETE FROM relationships WHERE from_character_id IN (${chars}) OR to_character_id IN (${chars})`,
      args: [...args, ...args],
    },
    { sql: `DELETE FROM characters WHERE series_id IN (${sel})`, args },
    { sql: `DELETE FROM volumes WHERE series_id IN (${sel})`, args },
    { sql: `DELETE FROM series_tags WHERE series_id IN (${sel})`, args },
    { sql: `DELETE FROM series_genres WHERE series_id IN (${sel})`, args },
    { sql: `DELETE FROM series_content_warnings WHERE series_id IN (${sel})`, args },
    { sql: `DELETE FROM gallery_images WHERE series_id IN (${sel})`, args },
    { sql: `DELETE FROM link_attachments WHERE series_id IN (${sel})`, args },
    { sql: `DELETE FROM attachments WHERE series_id IN (${sel})`, args },
    { sql: `DELETE FROM glossary_terms WHERE series_id IN (${sel})`, args },
    { sql: `DELETE FROM series_group_items WHERE series_id IN (${sel})`, args },
  ];
}

// ─── Series columns (whitelist; client sends snake_case keys) ────────

const SERIES_COLS = [
  'title', 'author', 'status', 'synopsis', 'library_id', 'kind', 'overall_thoughts',
  'chapter_thoughts', 'cover_image_path', 'book_type', 'rating', 'original_language',
  'country_of_origin', 'language_read', 'artist', 'year_published', 'date_started',
  'date_finished', 'status_country_of_origin', 'licensed_english', 'completely_translated',
  'original_publisher', 'english_publisher', 'is_nsfw', 'standalone_chapter_count', 'fandom',
] as const;

const SERIES_INT_COLS = new Set(['library_id', 'rating', 'is_nsfw', 'standalone_chapter_count']);

function seriesValues(raw: Args): any[] {
  if (!raw || typeof raw !== 'object') throw bad('Missing series');
  return SERIES_COLS.map((col) => {
    const v = raw[col];
    if (col === 'is_nsfw') return optInt(v) ? 1 : 0; // NOT NULL column
    if (SERIES_INT_COLS.has(col)) return optInt(v);
    const out = optStr(v);
    if (out === null && col === 'kind') return 'series';
    if (out === null && col === 'status') return 'Planning';
    return out;
  });
}

const SERIES_SELECT = `
  SELECT s.*,
    (SELECT GROUP_CONCAT(t.id || '::' || t.name || '::' || t.color, '||')
       FROM series_tags st JOIN tags t ON st.tag_id = t.id
       WHERE st.series_id = s.id) as tag_data,
    (SELECT GROUP_CONCAT(g.id || '::' || g.name || '::' || g.color, '||')
       FROM series_genres sg JOIN genres g ON sg.genre_id = g.id
       WHERE sg.series_id = s.id) as genre_data,
    (SELECT GROUP_CONCAT(cw.id || '::' || cw.name, '||')
       FROM series_content_warnings scw JOIN content_warnings cw ON scw.warning_id = cw.id
       WHERE scw.series_id = s.id) as warning_data,
    (SELECT COUNT(*) FROM volumes v WHERE v.series_id = s.id) as volume_count,
    (SELECT COUNT(*) FROM characters c WHERE c.series_id = s.id) as character_count
  FROM series s
`;

const TAG_PALETTE = [
  '#5DC8CD', '#9B7EDE', '#E58FB1', '#7FC9A0', '#B9BEC7', '#E8C15C', '#6FA8DC',
  '#4FBDB0', '#B0A15A', '#DD7A6E', '#E3A15C', '#8D9DE8', '#C98BC9', '#7FBF7F',
];

/** Deterministic tag colour (hash of the name), matching the client. */
function colorForTagName(name: string): string {
  let h = 0;
  for (const ch of name.trim().toLowerCase()) h = (h * 31 + ch.charCodeAt(0)) >>> 0;
  return TAG_PALETTE[h % TAG_PALETTE.length];
}

/** Replace a title's tags/genres/warnings in one transaction. */
async function syncLabels(
  ctx: Ctx,
  seriesId: number,
  tags: string[],
  genres: string[],
  warnings: string[]
): Promise<void> {
  const u = ctx.userId;
  const stmts: Array<{ sql: string; args?: any[] }> = [
    { sql: 'DELETE FROM series_tags WHERE series_id = ?', args: [seriesId] },
    { sql: 'DELETE FROM series_genres WHERE series_id = ?', args: [seriesId] },
    { sql: 'DELETE FROM series_content_warnings WHERE series_id = ?', args: [seriesId] },
  ];
  for (const t of tags) {
    stmts.push({
      sql: 'INSERT OR IGNORE INTO tags (owner_id, name, color) VALUES (?, ?, ?)',
      args: [u, t, colorForTagName(t)],
    });
    stmts.push({
      sql: `INSERT OR IGNORE INTO series_tags (series_id, tag_id)
            SELECT ?, id FROM tags WHERE owner_id = ? AND name = ?`,
      args: [seriesId, u, t],
    });
  }
  for (const g of genres) {
    stmts.push({ sql: 'INSERT OR IGNORE INTO genres (name) VALUES (?)', args: [g] });
    stmts.push({
      sql: `INSERT OR IGNORE INTO series_genres (series_id, genre_id)
            SELECT ?, id FROM genres WHERE name = ?`,
      args: [seriesId, g],
    });
  }
  for (const w of warnings) {
    stmts.push({
      sql: 'INSERT OR IGNORE INTO content_warnings (owner_id, name) VALUES (?, ?)',
      args: [u, w],
    });
    stmts.push({
      sql: `INSERT OR IGNORE INTO series_content_warnings (series_id, warning_id)
            SELECT ?, id FROM content_warnings WHERE owner_id = ? AND name = ?`,
      args: [seriesId, u, w],
    });
  }
  await ctx.db.transaction(stmts);
}

// ─── Child tables (all keyed by series_id) ───────────────────────────

interface ChildDef {
  cols: string[];
  intCols?: string[];
  order: string;
}

const CHILD: Record<string, ChildDef> = {
  volumes: {
    cols: [
      'volume_number', 'title', 'chapter_range', 'chapter_count', 'thoughts', 'chapter_notes',
      'cover_image_path', 'date_read', 'published_date',
    ],
    intCols: ['volume_number', 'chapter_count'],
    order: 'volume_number ASC',
  },
  characters: {
    cols: [
      'name', 'role', 'volume_appearances', 'notes', 'profile_image_path', 'status_role',
      'overall_vibes', 'appears_vs_reality', 'appears_text', 'reality_text', 'personality',
      'age', 'life_status',
    ],
    order: 'name COLLATE NOCASE',
  },
  gallery_images: {
    cols: ['image_path', 'caption', 'position'],
    intCols: ['position'],
    order: 'position, id',
  },
  link_attachments: { cols: ['url', 'label'], order: 'id DESC' },
  attachments: {
    cols: ['file_path', 'file_name', 'file_size'],
    intCols: ['file_size'],
    order: 'created_at DESC, id DESC',
  },
  glossary_terms: { cols: ['term', 'definition'], order: 'term COLLATE NOCASE' },
};

/** Columns that hold an R2 key, per child table (swept when a row goes). */
const CHILD_ASSET_COL: Record<string, string> = {
  volumes: 'cover_image_path',
  characters: 'profile_image_path',
  gallery_images: 'image_path',
  attachments: 'file_path',
};

function childDef(table: unknown): ChildDef & { name: string } {
  if (typeof table !== 'string' || !Object.prototype.hasOwnProperty.call(CHILD, table)) {
    throw bad('Unknown table');
  }
  return { ...CHILD[table], name: table };
}

function childValues(def: ChildDef, row: Args): any[] {
  if (!row || typeof row !== 'object') throw bad('Missing row');
  const ints = new Set(def.intCols ?? []);
  return def.cols.map((c) => (ints.has(c) ? optInt(row[c]) : optStr(row[c])));
}

/** Row id -> series id, proving the caller owns the parent title. */
async function requireChildRow(ctx: Ctx, table: string, id: number): Promise<number> {
  const r = await ctx.db.execute(
    `SELECT series_id FROM ${table} WHERE id = ? AND series_id IN (${OWNED_SERIES})`,
    [id, ctx.userId]
  );
  if (r.rows.length === 0) throw notFound();
  return r.rows[0].series_id as number;
}

// ─── Reading statuses ────────────────────────────────────────────────

const DEFAULT_STATUSES: Array<[string, string]> = [
  ['Reading', '#9B7EDE'],
  ['Finished', '#7FC9A0'],
  ['On Hold', '#E8C15C'],
  ['Planning', '#6FA8DC'],
  ['Dropped', '#DD7A6E'],
];

async function listStatuses(ctx: Ctx) {
  const q = () =>
    ctx.db.execute('SELECT * FROM reading_statuses WHERE owner_id = ? ORDER BY position, id', [
      ctx.userId,
    ]);
  let res = await q();
  if (res.rows.length === 0) {
    await ctx.db.transaction(
      DEFAULT_STATUSES.map(([name, color], i) => ({
        sql: 'INSERT OR IGNORE INTO reading_statuses (owner_id, name, color, position) VALUES (?, ?, ?, ?)',
        args: [ctx.userId, name, color, i],
      }))
    );
    res = await q();
  }
  return res.rows;
}

// ─── Settings ────────────────────────────────────────────────────────

const ALLOWED_SETTING_KEYS = new Set([
  'themeMode',
  'colorPaletteId',
  'showNsfwContent',
  'defaultStartTab',
  'autoOpenDetailAfterAdd',
  'annualReadingGoal',
]);

// ─── Operations ──────────────────────────────────────────────────────

const ops: Record<string, Handler> = {
  // Libraries
  async 'libraries.getAll'(ctx) {
    const q = () =>
      ctx.db.execute(
        `SELECT l.*, COUNT(s.id) as series_count
         FROM libraries l LEFT JOIN series s ON s.library_id = l.id
         WHERE l.owner_id = ? GROUP BY l.id ORDER BY l.position, l.id`,
        [ctx.userId]
      );
    let res = await q();
    if (res.rows.length === 0) {
      await ctx.db.execute(
        `INSERT INTO libraries (owner_id, name, icon, position) VALUES (?, 'Default Library', 'book', 0)`,
        [ctx.userId]
      );
      res = await q();
    }
    return { rows: res.rows };
  },

  async 'libraries.create'(ctx) {
    const name = str(ctx.a.name, 'name', 200).trim();
    if (!name) throw bad('Library name required');
    const pos = await ctx.db.execute(
      'SELECT COALESCE(MAX(position), -1) + 1 AS p FROM libraries WHERE owner_id = ?',
      [ctx.userId]
    );
    const r = await ctx.db.execute(
      'INSERT INTO libraries (owner_id, name, icon, icon_image, position) VALUES (?, ?, ?, ?, ?)',
      [ctx.userId, name, optStr(ctx.a.icon, 100) || 'grid', optStr(ctx.a.iconImage, 500), pos.rows[0].p]
    );
    return { id: r.lastInsertRowid };
  },

  async 'libraries.update'(ctx) {
    const id = int(ctx.a.id, 'id');
    await requireLibrary(ctx, id);
    await ctx.db.execute(
      'UPDATE libraries SET name = ?, icon = ?, icon_image = ? WHERE id = ? AND owner_id = ?',
      [str(ctx.a.name, 'name', 200), optStr(ctx.a.icon, 100), optStr(ctx.a.iconImage, 500), id, ctx.userId]
    );
    return { success: true };
  },

  async 'libraries.delete'(ctx) {
    const id = int(ctx.a.id, 'id');
    await requireLibrary(ctx, id);
    const sel = 'SELECT id FROM series WHERE library_id = ?';
    const keys = await assetKeysForSeries(ctx, sel, [id]);
    const icon = await ctx.db.execute('SELECT icon_image FROM libraries WHERE id = ?', [id]);
    await ctx.db.transaction([
      ...seriesChildDeletes(sel, [id]),
      {
        sql: 'DELETE FROM series_group_items WHERE group_id IN (SELECT id FROM series_groups WHERE library_id = ?)',
        args: [id],
      },
      { sql: 'DELETE FROM series_groups WHERE library_id = ?', args: [id] },
      { sql: 'DELETE FROM series WHERE library_id = ?', args: [id] },
      { sql: 'DELETE FROM libraries WHERE id = ? AND owner_id = ?', args: [id, ctx.userId] },
    ]);
    await sweepAssets(ctx, [...keys, icon.rows[0]?.icon_image]);
    return { success: true };
  },

  async 'libraries.reorder'(ctx) {
    const ids = intList(ctx.a.ids);
    if (ids.length === 0) return { success: true };
    await ctx.db.transaction(
      ids.map((id, i) => ({
        sql: 'UPDATE libraries SET position = ? WHERE id = ? AND owner_id = ?',
        args: [i, id, ctx.userId],
      }))
    );
    return { success: true };
  },

  // Series
  async 'series.getAll'(ctx) {
    const f = ctx.a;
    const where = ['s.library_id IN (SELECT id FROM libraries WHERE owner_id = ?)'];
    const args: any[] = [ctx.userId];

    if (f.includeNsfw === false) where.push('s.is_nsfw = 0');
    const libId = optInt(f.libraryId);
    if (libId && libId > 0) {
      where.push('s.library_id = ?');
      args.push(libId);
    }
    const eq = (cond: string, v: unknown, wrap = (x: string) => x) => {
      if (typeof v === 'string' && v.length > 0 && v.length <= 200) {
        where.push(cond);
        args.push(wrap(v));
      }
    };
    const like = (x: string) => `%${x}%`;

    if (f.status && f.status !== 'All') eq('s.status = ?', f.status);
    if (typeof f.search === 'string' && f.search.trim()) {
      where.push('(s.title LIKE ? OR s.author LIKE ? OR s.fandom LIKE ?)');
      const t = like(f.search.trim().slice(0, 200));
      args.push(t, t, t);
    }
    const minRating = optInt(f.minRating);
    if (minRating && minRating > 0) {
      where.push('s.rating >= ?');
      args.push(minRating);
    }
    const yf = optInt(f.yearFrom);
    if (yf !== null) {
      where.push(`s.year_published IS NOT NULL AND s.year_published != '' AND CAST(s.year_published AS INTEGER) >= ?`);
      args.push(yf);
    }
    const yt = optInt(f.yearTo);
    if (yt !== null) {
      where.push(`s.year_published IS NOT NULL AND s.year_published != '' AND CAST(s.year_published AS INTEGER) <= ?`);
      args.push(yt);
    }
    eq('s.book_type = ?', f.bookType);
    eq('s.language_read = ?', f.languageRead);
    eq('s.original_language LIKE ?', f.originalLanguage, like);
    eq('s.country_of_origin LIKE ?', f.countryOfOrigin, like);
    eq('s.completely_translated = ?', f.translationStatus);
    eq('s.author LIKE ?', f.author, like);
    eq('s.artist LIKE ?', f.artist, like);
    if (typeof f.publisher === 'string' && f.publisher) {
      where.push('(s.original_publisher LIKE ? OR s.english_publisher LIKE ?)');
      const t = like(f.publisher.slice(0, 200));
      args.push(t, t);
    }

    const labelFilter = (
      names: string[],
      matchAll: boolean,
      link: string,
      dim: string,
      nameCol: string
    ) => {
      if (names.length === 0) return;
      const ph = names.map(() => '?').join(',');
      if (matchAll) {
        where.push(`(SELECT COUNT(DISTINCT x.name) FROM ${link} l JOIN ${dim} x ON l.${nameCol} = x.id
                     WHERE l.series_id = s.id AND x.name IN (${ph})) = ?`);
        args.push(...names, names.length);
      } else {
        where.push(`s.id IN (SELECT l.series_id FROM ${link} l JOIN ${dim} x ON l.${nameCol} = x.id
                     WHERE x.name IN (${ph}))`);
        args.push(...names);
      }
    };
    labelFilter(strList(f.genres), !!f.matchAllGenres, 'series_genres', 'genres', 'genre_id');
    labelFilter(strList(f.tags), !!f.matchAllTags, 'series_tags', 'tags', 'tag_id');

    const dir = f.sortAsc === false ? 'DESC' : 'ASC';
    const orders: Record<string, string> = {
      rating: `s.rating ${dir}, s.title ASC`,
      id: `s.id ${dir}`,
      author: `s.author COLLATE NOCASE ${dir}, s.title ASC`,
      year: `CAST(s.year_published AS INTEGER) ${dir}, s.title ASC`,
      date_started: `s.date_started ${dir}, s.title ASC`,
      date_finished: `s.date_finished ${dir}, s.title ASC`,
    };
    const order = orders[String(f.sortBy)] ?? `s.title COLLATE NOCASE ${dir}`;

    const res = await ctx.db.execute(
      `${SERIES_SELECT} WHERE ${where.join(' AND ')} ORDER BY ${order}`,
      args
    );
    return { rows: res.rows };
  },

  async 'series.getById'(ctx) {
    const res = await ctx.db.execute(
      `${SERIES_SELECT} WHERE s.id = ? AND s.library_id IN (SELECT id FROM libraries WHERE owner_id = ?)`,
      [int(ctx.a.id, 'id'), ctx.userId]
    );
    return { row: res.rows[0] ?? null };
  },

  async 'series.create'(ctx) {
    const values = seriesValues(ctx.a.series);
    const libraryId = int(values[SERIES_COLS.indexOf('library_id')], 'library_id');
    await requireLibrary(ctx, libraryId);
    if (!values[0]) throw bad('Title required');

    const r = await ctx.db.execute(
      `INSERT INTO series (${SERIES_COLS.join(', ')}, created_at) VALUES (${SERIES_COLS.map(() => '?').join(', ')}, datetime('now'))`,
      values
    );
    const id = r.lastInsertRowid ?? 0;
    try {
      await syncLabels(ctx, id, strList(ctx.a.tagNames), strList(ctx.a.genreNames), strList(ctx.a.warningNames));
    } catch (err) {
      await ctx.db.execute('DELETE FROM series WHERE id = ?', [id]);
      throw err;
    }
    return { id };
  },

  async 'series.update'(ctx) {
    const id = int(ctx.a.id, 'id');
    await requireSeries(ctx, id);
    const values = seriesValues(ctx.a.series);
    // Moving a title is only allowed into a library the caller owns.
    await requireLibrary(ctx, int(values[SERIES_COLS.indexOf('library_id')], 'library_id'));
    await ctx.db.execute(
      `UPDATE series SET ${SERIES_COLS.map((c) => `${c} = ?`).join(', ')} WHERE id = ?`,
      [...values, id]
    );
    await syncLabels(ctx, id, strList(ctx.a.tagNames), strList(ctx.a.genreNames), strList(ctx.a.warningNames));
    return { success: true };
  },

  async 'series.delete'(ctx) {
    const id = int(ctx.a.id, 'id');
    await requireSeries(ctx, id);
    const keys = await assetKeysForSeries(ctx, '?', [id]);
    await ctx.db.transaction([
      ...seriesChildDeletes('?', [id]),
      { sql: 'DELETE FROM series WHERE id = ?', args: [id] },
    ]);
    await sweepAssets(ctx, keys);
    return { success: true };
  },

  // Apply one action to many titles at once. Ids the caller doesn't own are
  // silently dropped (the response says how many were affected).
  async 'series.bulk'(ctx) {
    const ids = intList(ctx.a.ids, 500);
    if (ids.length === 0) throw bad('No titles selected');
    const action = str(ctx.a.action, 'action', 30);
    const owned = (
      await ctx.db.execute(
        `SELECT s.id FROM series s JOIN libraries l ON l.id = s.library_id
         WHERE l.owner_id = ? AND s.id IN (${ids.map(() => '?').join(',')})`,
        [ctx.userId, ...ids]
      )
    ).rows.map((r) => r.id as number);
    if (owned.length === 0) throw notFound('Titles not found');
    const inList = owned.map(() => '?').join(',');

    switch (action) {
      case 'status': {
        const status = str(ctx.a.status, 'status', 100).trim();
        if (!status) throw bad('Status required');
        await ctx.db.execute(`UPDATE series SET status = ? WHERE id IN (${inList})`, [status, ...owned]);
        break;
      }
      case 'move': {
        const target = int(ctx.a.targetLibraryId, 'targetLibraryId');
        await requireLibrary(ctx, target);
        await ctx.db.transaction([
          {
            sql: `DELETE FROM series_group_items WHERE series_id IN
                  (SELECT id FROM series WHERE id IN (${inList}) AND library_id != ?)`,
            args: [...owned, target],
          },
          { sql: `UPDATE series SET library_id = ? WHERE id IN (${inList})`, args: [target, ...owned] },
        ]);
        break;
      }
      case 'addTags':
      case 'removeTags': {
        const tags = strList(ctx.a.tags, 10);
        if (tags.length === 0) throw bad('Tags required');
        const stmts: Array<{ sql: string; args?: any[] }> = [];
        if (action === 'addTags') {
          for (const t of tags) {
            stmts.push({
              sql: 'INSERT OR IGNORE INTO tags (owner_id, name, color) VALUES (?, ?, ?)',
              args: [ctx.userId, t, colorForTagName(t)],
            });
            stmts.push({
              sql: `INSERT OR IGNORE INTO series_tags (series_id, tag_id)
                    SELECT s.id, (SELECT id FROM tags WHERE owner_id = ? AND name = ?)
                    FROM series s WHERE s.id IN (${inList})`,
              args: [ctx.userId, t, ...owned],
            });
          }
        } else {
          stmts.push({
            sql: `DELETE FROM series_tags WHERE series_id IN (${inList}) AND tag_id IN
                  (SELECT id FROM tags WHERE owner_id = ? AND name IN (${tags.map(() => '?').join(',')}))`,
            args: [...owned, ctx.userId, ...tags],
          });
        }
        await ctx.db.transaction(stmts);
        break;
      }
      case 'delete': {
        const keys = await assetKeysForSeries(ctx, inList, owned);
        await ctx.db.transaction([
          ...seriesChildDeletes(inList, owned),
          { sql: `DELETE FROM series WHERE id IN (${inList})`, args: owned },
        ]);
        await sweepAssets(ctx, keys);
        break;
      }
      default:
        throw bad('Unknown bulk action');
    }
    return { affected: owned.length };
  },

  async 'series.transfer'(ctx) {
    const id = int(ctx.a.id, 'id');
    const target = int(ctx.a.targetLibraryId, 'targetLibraryId');
    await requireSeries(ctx, id);
    await requireLibrary(ctx, target);
    await ctx.db.transaction([
      // Groups are library-scoped, so a title moving elsewhere leaves them.
      {
        sql: 'DELETE FROM series_group_items WHERE series_id = ? AND series_id IN (SELECT id FROM series WHERE id = ? AND library_id != ?)',
        args: [id, id, target],
      },
      { sql: 'UPDATE series SET library_id = ? WHERE id = ?', args: [target, id] },
    ]);
    return { success: true };
  },

  async 'series.copy'(ctx) {
    const id = int(ctx.a.id, 'id');
    const target = int(ctx.a.targetLibraryId, 'targetLibraryId');
    await requireSeries(ctx, id);
    await requireLibrary(ctx, target);

    const orig = (await ctx.db.execute('SELECT * FROM series WHERE id = ?', [id])).rows[0];
    const values = SERIES_COLS.map((c) => (c === 'library_id' ? target : orig[c] ?? null));
    const created = await ctx.db.execute(
      `INSERT INTO series (${SERIES_COLS.join(', ')}, created_at) VALUES (${SERIES_COLS.map(() => '?').join(', ')}, datetime('now'))`,
      values
    );
    const newId = created.lastInsertRowid ?? 0;

    try {
      const stmts: Array<{ sql: string; args?: any[] }> = [
        {
          sql: 'INSERT OR IGNORE INTO series_tags (series_id, tag_id) SELECT ?, tag_id FROM series_tags WHERE series_id = ?',
          args: [newId, id],
        },
        {
          sql: 'INSERT OR IGNORE INTO series_genres (series_id, genre_id) SELECT ?, genre_id FROM series_genres WHERE series_id = ?',
          args: [newId, id],
        },
        {
          sql: 'INSERT OR IGNORE INTO series_content_warnings (series_id, warning_id) SELECT ?, warning_id FROM series_content_warnings WHERE series_id = ?',
          args: [newId, id],
        },
      ];
      const copyChild = (table: string, on: boolean) => {
        if (!on) return;
        const cols = CHILD[table].cols.join(', ');
        stmts.push({
          sql: `INSERT INTO ${table} (series_id, ${cols}) SELECT ?, ${cols} FROM ${table} WHERE series_id = ?`,
          args: [newId, id],
        });
      };
      copyChild('volumes', ctx.a.includeVolumes !== false);
      copyChild('gallery_images', ctx.a.includeGallery !== false);
      copyChild('attachments', ctx.a.includeAttachments !== false);
      copyChild('link_attachments', ctx.a.includeAttachments !== false);
      await ctx.db.transaction(stmts);

      if (ctx.a.includeCharacters !== false) {
        const chars = (
          await ctx.db.execute('SELECT * FROM characters WHERE series_id = ?', [id])
        ).rows;
        const idMap = new Map<number, number>();
        const cols = CHILD.characters.cols;
        for (const ch of chars) {
          const r = await ctx.db.execute(
            `INSERT INTO characters (series_id, ${cols.join(', ')}) VALUES (?, ${cols.map(() => '?').join(', ')})`,
            [newId, ...cols.map((c) => ch[c] ?? null)]
          );
          idMap.set(ch.id, r.lastInsertRowid ?? 0);
        }
        const rels = (
          await ctx.db.execute(
            `SELECT r.* FROM relationships r JOIN characters c ON c.id = r.from_character_id WHERE c.series_id = ?`,
            [id]
          )
        ).rows;
        const relStmts = rels
          .filter((r) => idMap.has(r.from_character_id) && idMap.has(r.to_character_id))
          .map((r) => ({
            sql: `INSERT INTO relationships (from_character_id, to_character_id, type, label, is_bidirectional, notes)
                  VALUES (?, ?, ?, ?, ?, ?)`,
            args: [idMap.get(r.from_character_id), idMap.get(r.to_character_id), r.type, r.label, r.is_bidirectional, r.notes],
          }));
        if (relStmts.length) await ctx.db.transaction(relStmts);
      }
    } catch (err) {
      // Roll the half-built copy back. Shared R2 keys are untouched because
      // the sweep only removes keys nothing references any more.
      await ops['series.delete']({ ...ctx, a: { id: newId } }).catch(() => {});
      throw err;
    }
    return { id: newId };
  },

  // Child tables
  async 'child.list'(ctx) {
    const def = childDef(ctx.a.table);
    const seriesId = int(ctx.a.seriesId, 'seriesId');
    await requireSeries(ctx, seriesId);
    const r = await ctx.db.execute(
      `SELECT * FROM ${def.name} WHERE series_id = ? ORDER BY ${def.order}`,
      [seriesId]
    );
    return { rows: r.rows };
  },

  async 'child.create'(ctx) {
    const def = childDef(ctx.a.table);
    const seriesId = int(ctx.a.seriesId, 'seriesId');
    await requireSeries(ctx, seriesId);
    const r = await ctx.db.execute(
      `INSERT INTO ${def.name} (series_id, ${def.cols.join(', ')}) VALUES (?, ${def.cols.map(() => '?').join(', ')})`,
      [seriesId, ...childValues(def, ctx.a.row)]
    );
    return { id: r.lastInsertRowid };
  },

  async 'child.update'(ctx) {
    const def = childDef(ctx.a.table);
    const id = int(ctx.a.id, 'id');
    await requireChildRow(ctx, def.name, id);
    const assetCol = CHILD_ASSET_COL[def.name];
    const before = assetCol
      ? (await ctx.db.execute(`SELECT ${assetCol} AS k FROM ${def.name} WHERE id = ?`, [id])).rows[0]?.k
      : null;
    await ctx.db.execute(
      `UPDATE ${def.name} SET ${def.cols.map((c) => `${c} = ?`).join(', ')} WHERE id = ?`,
      [...childValues(def, ctx.a.row), id]
    );
    if (before) await sweepAssets(ctx, [before]);
    return { success: true };
  },

  async 'child.delete'(ctx) {
    const def = childDef(ctx.a.table);
    const id = int(ctx.a.id, 'id');
    await requireChildRow(ctx, def.name, id);
    const assetCol = CHILD_ASSET_COL[def.name];
    const before = assetCol
      ? (await ctx.db.execute(`SELECT ${assetCol} AS k FROM ${def.name} WHERE id = ?`, [id])).rows[0]?.k
      : null;
    const stmts: Array<{ sql: string; args?: any[] }> = [];
    if (def.name === 'characters') {
      stmts.push({
        sql: 'DELETE FROM relationships WHERE from_character_id = ? OR to_character_id = ?',
        args: [id, id],
      });
    }
    stmts.push({ sql: `DELETE FROM ${def.name} WHERE id = ?`, args: [id] });
    await ctx.db.transaction(stmts);
    if (before) await sweepAssets(ctx, [before]);
    return { success: true };
  },

  // Relationships
  async 'relationships.list'(ctx) {
    const seriesId = int(ctx.a.seriesId, 'seriesId');
    await requireSeries(ctx, seriesId);
    const r = await ctx.db.execute(
      `SELECT r.*,
         c1.name as from_character_name, c1.profile_image_path as from_character_image,
         c2.name as to_character_name, c2.profile_image_path as to_character_image
       FROM relationships r
       JOIN characters c1 ON r.from_character_id = c1.id
       JOIN characters c2 ON r.to_character_id = c2.id
       WHERE c1.series_id = ?`,
      [seriesId]
    );
    return { rows: r.rows };
  },

  async 'relationships.create'(ctx) {
    const from = int(ctx.a.fromCharacterId, 'fromCharacterId');
    const to = int(ctx.a.toCharacterId, 'toCharacterId');
    await requireCharacter(ctx, from);
    await requireCharacter(ctx, to);
    const r = await ctx.db.execute(
      `INSERT INTO relationships (from_character_id, to_character_id, type, label, is_bidirectional, notes)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [from, to, optStr(ctx.a.type, 100), optStr(ctx.a.label, 200), ctx.a.isBidirectional ? 1 : 0, optStr(ctx.a.notes)]
    );
    return { id: r.lastInsertRowid };
  },

  async 'relationships.update'(ctx) {
    const id = int(ctx.a.id, 'id');
    const from = int(ctx.a.fromCharacterId, 'fromCharacterId');
    const to = int(ctx.a.toCharacterId, 'toCharacterId');
    await requireRelationship(ctx, id);
    await requireCharacter(ctx, from);
    await requireCharacter(ctx, to);
    await ctx.db.execute(
      `UPDATE relationships SET from_character_id = ?, to_character_id = ?, type = ?, label = ?,
         is_bidirectional = ?, notes = ? WHERE id = ?`,
      [from, to, optStr(ctx.a.type, 100), optStr(ctx.a.label, 200), ctx.a.isBidirectional ? 1 : 0, optStr(ctx.a.notes), id]
    );
    return { success: true };
  },

  async 'relationships.delete'(ctx) {
    const id = int(ctx.a.id, 'id');
    await requireRelationship(ctx, id);
    await ctx.db.execute('DELETE FROM relationships WHERE id = ?', [id]);
    return { success: true };
  },

  // Groups
  async 'groups.getAll'(ctx) {
    const libraryId = int(ctx.a.libraryId, 'libraryId');
    await requireLibrary(ctx, libraryId);
    const groups = await ctx.db.execute(
      'SELECT * FROM series_groups WHERE library_id = ? ORDER BY position, id',
      [libraryId]
    );
    // One query for every member of every group (no per-group round trip).
    const items = await ctx.db.execute(
      `SELECT sgi.group_id, s.id, s.title, s.cover_image_path, s.status, s.kind, s.rating,
         (SELECT COUNT(*) FROM volumes v WHERE v.series_id = s.id) as volume_count,
         sgi.group_role, sgi.position
       FROM series_group_items sgi
       JOIN series s ON sgi.series_id = s.id
       WHERE sgi.group_id IN (SELECT id FROM series_groups WHERE library_id = ?)
       ORDER BY sgi.position`,
      [libraryId]
    );
    return { groups: groups.rows, items: items.rows };
  },

  async 'groups.create'(ctx) {
    const libraryId = int(ctx.a.libraryId, 'libraryId');
    await requireLibrary(ctx, libraryId);
    const members = await groupMembers(ctx);
    const pos = await ctx.db.execute(
      'SELECT COALESCE(MAX(position), -1) + 1 AS p FROM series_groups WHERE library_id = ?',
      [libraryId]
    );
    const r = await ctx.db.execute(
      'INSERT INTO series_groups (library_id, name, group_type, description, position) VALUES (?, ?, ?, ?, ?)',
      [
        libraryId,
        str(ctx.a.name, 'name', 200),
        optStr(ctx.a.groupType, 100) || 'Series Group',
        optStr(ctx.a.description),
        pos.rows[0].p,
      ]
    );
    const id = r.lastInsertRowid ?? 0;
    await replaceGroupItems(ctx, id, members);
    return { id };
  },

  async 'groups.update'(ctx) {
    const id = int(ctx.a.id, 'id');
    await requireGroup(ctx, id);
    const members = await groupMembers(ctx);
    await ctx.db.execute(
      'UPDATE series_groups SET name = ?, group_type = ?, description = ? WHERE id = ?',
      [str(ctx.a.name, 'name', 200), optStr(ctx.a.groupType, 100) || 'Series Group', optStr(ctx.a.description), id]
    );
    await replaceGroupItems(ctx, id, members);
    return { success: true };
  },

  async 'groups.delete'(ctx) {
    const id = int(ctx.a.id, 'id');
    await requireGroup(ctx, id);
    await ctx.db.transaction([
      { sql: 'DELETE FROM series_group_items WHERE group_id = ?', args: [id] },
      { sql: 'DELETE FROM series_groups WHERE id = ?', args: [id] },
    ]);
    return { success: true };
  },

  // Tags / genres / warnings
  async 'tags.getAll'(ctx) {
    const r = await ctx.db.execute('SELECT * FROM tags WHERE owner_id = ? ORDER BY name COLLATE NOCASE', [ctx.userId]);
    return { rows: r.rows };
  },

  async 'tags.update'(ctx) {
    const r = await ctx.db.execute('UPDATE tags SET name = ?, color = ? WHERE id = ? AND owner_id = ?', [
      str(ctx.a.name, 'name', 200),
      optStr(ctx.a.color, 20),
      int(ctx.a.id, 'id'),
      ctx.userId,
    ]);
    if (r.affectedRows === 0) throw notFound('Tag not found');
    return { success: true };
  },

  async 'tags.delete'(ctx) {
    const id = int(ctx.a.id, 'id');
    const own = await ctx.db.execute('SELECT id FROM tags WHERE id = ? AND owner_id = ?', [id, ctx.userId]);
    if (own.rows.length === 0) throw notFound('Tag not found');
    await ctx.db.transaction([
      { sql: 'DELETE FROM series_tags WHERE tag_id = ?', args: [id] },
      { sql: 'DELETE FROM tags WHERE id = ? AND owner_id = ?', args: [id, ctx.userId] },
    ]);
    return { success: true };
  },

  // Genres are a shared, read-only vocabulary.
  async 'genres.getAll'(ctx) {
    const r = await ctx.db.execute('SELECT * FROM genres ORDER BY name COLLATE NOCASE');
    return { rows: r.rows };
  },

  async 'warnings.getAll'(ctx) {
    const r = await ctx.db.execute(
      'SELECT * FROM content_warnings WHERE owner_id = ? ORDER BY name COLLATE NOCASE',
      [ctx.userId]
    );
    return { rows: r.rows };
  },

  // Persist a drag-to-reorder of a title's gallery. Ids that don't belong to
  // the title are ignored by the series_id guard.
  async 'gallery.reorder'(ctx) {
    const seriesId = int(ctx.a.seriesId, 'seriesId');
    await requireSeries(ctx, seriesId);
    const ids = intList(ctx.a.ids);
    if (ids.length === 0) return { success: true };
    await ctx.db.transaction(
      ids.map((id, i) => ({
        sql: 'UPDATE gallery_images SET position = ? WHERE id = ? AND series_id = ?',
        args: [i, id, seriesId],
      }))
    );
    return { success: true };
  },

  // Reading statuses
  async 'statuses.getAll'(ctx) {
    return { rows: await listStatuses(ctx) };
  },

  async 'statuses.create'(ctx) {
    const pos = await ctx.db.execute(
      'SELECT COALESCE(MAX(position), -1) + 1 AS p FROM reading_statuses WHERE owner_id = ?',
      [ctx.userId]
    );
    const r = await ctx.db.execute(
      'INSERT INTO reading_statuses (owner_id, name, color, position) VALUES (?, ?, ?, ?)',
      [ctx.userId, str(ctx.a.name, 'name', 100), optStr(ctx.a.color, 20), pos.rows[0].p]
    );
    return { id: r.lastInsertRowid };
  },

  async 'statuses.update'(ctx) {
    const id = int(ctx.a.id, 'id');
    const cur = await ctx.db.execute('SELECT name FROM reading_statuses WHERE id = ? AND owner_id = ?', [id, ctx.userId]);
    if (cur.rows.length === 0) throw notFound('Status not found');
    const name = str(ctx.a.name, 'name', 100);
    const prev = cur.rows[0].name as string;
    const stmts: Array<{ sql: string; args?: any[] }> = [
      {
        sql: 'UPDATE reading_statuses SET name = ?, color = ? WHERE id = ? AND owner_id = ?',
        args: [name, optStr(ctx.a.color, 20), id, ctx.userId],
      },
    ];
    if (prev !== name) {
      // Scoped to the caller's own titles (the old client query was global).
      stmts.push({
        sql: `UPDATE series SET status = ? WHERE status = ? AND library_id IN (SELECT id FROM libraries WHERE owner_id = ?)`,
        args: [name, prev, ctx.userId],
      });
    }
    await ctx.db.transaction(stmts);
    return { success: true };
  },

  async 'statuses.delete'(ctx) {
    const id = int(ctx.a.id, 'id');
    const cur = await ctx.db.execute('SELECT name FROM reading_statuses WHERE id = ? AND owner_id = ?', [id, ctx.userId]);
    if (cur.rows.length === 0) throw notFound('Status not found');
    await ctx.db.transaction([
      {
        sql: `UPDATE series SET status = ? WHERE status = ? AND library_id IN (SELECT id FROM libraries WHERE owner_id = ?)`,
        args: [optStr(ctx.a.fallbackName, 100) || 'Planning', cur.rows[0].name, ctx.userId],
      },
      { sql: 'DELETE FROM reading_statuses WHERE id = ? AND owner_id = ?', args: [id, ctx.userId] },
    ]);
    return { success: true };
  },

  // Settings
  // ─── Backup: export everything the caller owns / additive restore ────
  async 'data.export'(ctx) {
    const u = [ctx.userId];
    const childTables = Object.keys(CHILD);
    const res = await ctx.db.batch([
      { sql: 'SELECT id, name, icon, icon_image, position FROM libraries WHERE owner_id = ? ORDER BY position, id', args: u },
      {
        sql: `SELECT s.id, s.created_at, ${SERIES_COLS.map((c) => `s.${c}`).join(', ')}
              FROM series s JOIN libraries l ON l.id = s.library_id WHERE l.owner_id = ? ORDER BY s.id`,
        args: u,
      },
      ...childTables.map((t) => ({
        sql: `SELECT id, series_id, ${CHILD[t].cols.join(', ')} FROM ${t}
              WHERE series_id IN (${OWNED_SERIES}) ORDER BY id`,
        args: u,
      })),
      {
        sql: `SELECT r.from_character_id, r.to_character_id, r.type, r.label, r.is_bidirectional, r.notes
              FROM relationships r JOIN characters c ON c.id = r.from_character_id
              WHERE c.series_id IN (${OWNED_SERIES}) ORDER BY r.id`,
        args: u,
      },
      {
        sql: `SELECT st.series_id, t.name, t.color FROM series_tags st JOIN tags t ON t.id = st.tag_id
              WHERE st.series_id IN (${OWNED_SERIES})`,
        args: u,
      },
      {
        sql: `SELECT sg.series_id, g.name, g.color FROM series_genres sg JOIN genres g ON g.id = sg.genre_id
              WHERE sg.series_id IN (${OWNED_SERIES})`,
        args: u,
      },
      {
        sql: `SELECT sw.series_id, w.name FROM series_content_warnings sw
              JOIN content_warnings w ON w.id = sw.warning_id WHERE sw.series_id IN (${OWNED_SERIES})`,
        args: u,
      },
      {
        sql: `SELECT g.id, g.library_id, g.name, g.group_type, g.description, g.position
              FROM series_groups g JOIN libraries l ON l.id = g.library_id WHERE l.owner_id = ? ORDER BY g.id`,
        args: u,
      },
      {
        sql: `SELECT i.group_id, i.series_id, i.group_role, i.position FROM series_group_items i
              JOIN series_groups g ON g.id = i.group_id JOIN libraries l ON l.id = g.library_id
              WHERE l.owner_id = ?`,
        args: u,
      },
      { sql: 'SELECT name, color, position FROM reading_statuses WHERE owner_id = ? ORDER BY position, id', args: u },
    ]);

    const [libraries, series] = [res[0].rows, res[1].rows];
    const child: Record<string, any[]> = {};
    childTables.forEach((t, i) => (child[t] = res[2 + i].rows));
    const at = 2 + childTables.length;
    const [relationships, tagRows, genreRows, warnRows, groups, groupItems, statuses] = [
      res[at].rows, res[at + 1].rows, res[at + 2].rows, res[at + 3].rows,
      res[at + 4].rows, res[at + 5].rows, res[at + 6].rows,
    ];

    const bySeries = (rows: any[], pick: (r: any) => any) => {
      const m = new Map<number, any[]>();
      for (const r of rows) {
        const list = m.get(r.series_id) ?? [];
        list.push(pick(r));
        m.set(r.series_id, list);
      }
      return m;
    };
    const tags = bySeries(tagRows, (r) => ({ name: r.name, color: r.color }));
    const genres = bySeries(genreRows, (r) => ({ name: r.name, color: r.color }));
    const warnings = bySeries(warnRows, (r) => r.name);

    return {
      backup: {
        app: 'myaarchive',
        version: 3,
        exportedAt: new Date().toISOString(),
        libraries,
        series: series.map((s) => ({
          ...s,
          tags: tags.get(s.id) ?? [],
          genres: genres.get(s.id) ?? [],
          warnings: warnings.get(s.id) ?? [],
        })),
        volumes: child.volumes,
        characters: child.characters,
        relationships,
        gallery_images: child.gallery_images,
        link_attachments: child.link_attachments,
        attachments: child.attachments,
        glossary_terms: child.glossary_terms,
        series_groups: groups,
        series_group_items: groupItems,
        reading_statuses: statuses,
      },
    };
  },

  /**
   * Additive restore: every library in the file becomes a NEW library under
   * the caller (nothing existing is overwritten or merged). Accepts the v3
   * format above and the older desktop export (v2). Image/file keys are
   * re-linked, not re-uploaded, so they only resolve for the account that
   * owns those objects.
   */
  async 'data.import'(ctx) {
    const d = ctx.a.data;
    if (!d || typeof d !== 'object' || Array.isArray(d)) throw bad('Missing backup data');
    const rows = (key: string, max = 100_000): Args[] => {
      const v = (d as Args)[key];
      if (v === undefined || v === null) return [];
      if (!Array.isArray(v) || v.length > max) throw bad(`Invalid or too many ${key}`);
      return v.filter((x) => x && typeof x === 'object' && !Array.isArray(x));
    };
    const libs = rows('libraries', 500);
    const seriesIn = rows('series', 5000);
    if (libs.length === 0 && seriesIn.length === 0) throw bad('Nothing to import');
    const characters = rows('characters');
    const relationships = rows('relationships');
    const groups = rows('series_groups', 5000);
    const groupItems = rows('series_group_items');
    const statusesIn = rows('reading_statuses', 500);
    const childIn: Record<string, Args[]> = {};
    for (const t of Object.keys(CHILD)) childIn[t] = t === 'characters' ? characters : rows(t);

    // Allocate ids above the current maximum so the whole restore can be
    // sent as a few batched transactions instead of one round trip per row.
    const idTables = [
      'libraries', 'series', 'volumes', 'characters', 'relationships',
      'gallery_images', 'link_attachments', 'attachments', 'glossary_terms', 'series_groups',
    ];
    const maxRes = await ctx.db.batch([
      ...idTables.map((t) => ({ sql: `SELECT COALESCE(MAX(id), 0) AS m FROM ${t}` })),
      { sql: 'SELECT name FROM libraries WHERE owner_id = ?', args: [ctx.userId] },
    ]);
    const next: Record<string, number> = {};
    idTables.forEach((t, i) => (next[t] = Number(maxRes[i].rows[0]?.m ?? 0) + 1));
    const alloc = (t: string) => next[t]++;
    const existingNames = new Set<string>(maxRes[idTables.length].rows.map((r) => String(r.name).toLowerCase()));
    const basePos = maxRes[idTables.length].rows.length;

    const u = ctx.userId;
    const libStmts: Array<{ sql: string; args?: any[] }> = [];
    const libMap = new Map<number, number>();
    const newLibIds: number[] = [];
    const addLibrary = (name: string, icon: string | null, iconImage: string | null) => {
      let finalName = name;
      if (existingNames.has(finalName.toLowerCase())) finalName = `${name} (imported)`;
      let n = 2;
      while (existingNames.has(finalName.toLowerCase())) finalName = `${name} (imported ${n++})`;
      existingNames.add(finalName.toLowerCase());
      const id = alloc('libraries');
      newLibIds.push(id);
      libStmts.push({
        sql: 'INSERT INTO libraries (id, owner_id, name, icon, icon_image, position) VALUES (?, ?, ?, ?, ?, ?)',
        args: [id, u, finalName, icon || 'grid', iconImage, basePos + newLibIds.length - 1],
      });
      return id;
    };
    for (const l of libs) {
      const oldId = optInt(l.id);
      const id = addLibrary(
        (optStr(l.name, 200) || 'Library').trim() || 'Library',
        optStr(l.icon, 100),
        optStr(l.icon_image, 500)
      );
      if (oldId !== null) libMap.set(oldId, id);
    }
    let fallbackLib: number | null = null;
    const libraryFor = (oldId: unknown): number => {
      const m = libMap.get(optInt(oldId) ?? -1);
      if (m) return m;
      if (fallbackLib === null) fallbackLib = addLibrary('Imported', 'book', null);
      return fallbackLib;
    };

    const stmts: Array<{ sql: string; args?: any[] }> = [];
    let skipped = 0;

    // Labels (tags/genres/warnings) are created once, then linked by name.
    const color = (v: unknown): string | null =>
      typeof v === 'string' && /^#[0-9a-fA-F]{3,8}$/.test(v) ? v : null;
    type Label = { name: string; color: string | null };
    const labelList = (arr: unknown, legacy: unknown): Label[] => {
      const out: Label[] = [];
      if (Array.isArray(arr)) {
        for (const x of arr.slice(0, 100)) {
          if (typeof x === 'string') out.push({ name: x.trim(), color: null });
          else if (x && typeof x === 'object') out.push({ name: String((x as Args).name ?? '').trim(), color: color((x as Args).color) });
        }
      } else if (typeof legacy === 'string') {
        for (const part of legacy.split('||').slice(0, 100)) {
          const bits = part.split('::'); // id::name::color (desktop v2)
          if (bits.length >= 2) out.push({ name: bits[1].trim(), color: color(bits[2]) });
        }
      }
      return out.filter((l) => l.name.length > 0 && l.name.length <= 200);
    };
    const tagSet = new Map<string, Label>();
    const genreSet = new Map<string, Label>();
    const warnSet = new Map<string, Label>();
    const links: Array<{ sql: string; args: any[] }> = [];

    const seriesMap = new Map<number, number>();
    for (const s of seriesIn) {
      const title = optStr(s.title);
      if (!title || !title.trim()) { skipped++; continue; }
      const newId = alloc('series');
      const oldId = optInt(s.id);
      if (oldId !== null) seriesMap.set(oldId, newId);
      const values = seriesValues({ ...s, library_id: libraryFor(s.library_id) });
      stmts.push({
        sql: `INSERT INTO series (id, ${SERIES_COLS.join(', ')}, created_at)
              VALUES (?, ${SERIES_COLS.map(() => '?').join(', ')}, COALESCE(?, datetime('now')))`,
        args: [newId, ...values, optStr(s.created_at, 40)],
      });
      for (const t of labelList(s.tags, s.tag_data)) {
        tagSet.set(t.name.toLowerCase(), t);
        links.push({
          sql: `INSERT OR IGNORE INTO series_tags (series_id, tag_id)
                SELECT ?, id FROM tags WHERE owner_id = ? AND name = ?`,
          args: [newId, u, t.name],
        });
      }
      for (const g of labelList(s.genres, s.genre_data)) {
        genreSet.set(g.name.toLowerCase(), g);
        links.push({
          sql: `INSERT OR IGNORE INTO series_genres (series_id, genre_id)
                SELECT ?, id FROM genres WHERE name = ?`,
          args: [newId, g.name],
        });
      }
      for (const w of labelList(s.warnings, s.warning_data)) {
        warnSet.set(w.name.toLowerCase(), w);
        links.push({
          sql: `INSERT OR IGNORE INTO series_content_warnings (series_id, warning_id)
                SELECT ?, id FROM content_warnings WHERE owner_id = ? AND name = ?`,
          args: [newId, u, w.name],
        });
      }
    }

    // Label rows must exist before the link statements that select them.
    for (const t of tagSet.values()) {
      stmts.push({
        sql: 'INSERT OR IGNORE INTO tags (owner_id, name, color) VALUES (?, ?, ?)',
        args: [u, t.name, t.color ?? colorForTagName(t.name)],
      });
    }
    for (const g of genreSet.values()) {
      stmts.push({
        sql: "INSERT OR IGNORE INTO genres (name, color) VALUES (?, COALESCE(?, '#b2bec3'))",
        args: [g.name, g.color],
      });
    }
    for (const w of warnSet.values()) {
      stmts.push({
        sql: 'INSERT OR IGNORE INTO content_warnings (owner_id, name) VALUES (?, ?)',
        args: [u, w.name],
      });
    }
    stmts.push(...links);

    // Required (NOT NULL) fields per child table; rows missing one are skipped.
    const REQUIRED: Record<string, string[]> = {
      volumes: ['volume_number'],
      characters: ['name'],
      gallery_images: ['image_path'],
      link_attachments: ['url'],
      attachments: ['file_path', 'file_name'],
      glossary_terms: ['term'],
    };
    const charMap = new Map<number, number>();
    for (const t of Object.keys(CHILD)) {
      const def = CHILD[t];
      childIn[t].forEach((row, index) => {
        const sid = seriesMap.get(optInt(row.series_id) ?? -1);
        if (!sid) { skipped++; return; }
        const vals = childValues(def, row);
        const missing = REQUIRED[t].some((c) => vals[def.cols.indexOf(c)] === null);
        if (missing) { skipped++; return; }
        if (t === 'gallery_images') {
          const pi = def.cols.indexOf('position');
          if (vals[pi] === null) vals[pi] = index;
        }
        const id = alloc(t);
        const oldId = optInt(row.id);
        if (t === 'characters' && oldId !== null) charMap.set(oldId, id);
        stmts.push({
          sql: `INSERT INTO ${t} (id, series_id, ${def.cols.join(', ')})
                VALUES (?, ?, ${def.cols.map(() => '?').join(', ')})`,
          args: [id, sid, ...vals],
        });
      });
    }
    for (const r of relationships) {
      const from = charMap.get(optInt(r.from_character_id) ?? -1);
      const to = charMap.get(optInt(r.to_character_id) ?? -1);
      if (!from || !to) { skipped++; continue; }
      stmts.push({
        sql: `INSERT INTO relationships (id, from_character_id, to_character_id, type, label, is_bidirectional, notes)
              VALUES (?, ?, ?, ?, ?, ?, ?)`,
        args: [
          alloc('relationships'), from, to, optStr(r.type, 100) || 'Friend', optStr(r.label, 200),
          optInt(r.is_bidirectional) === 0 ? 0 : 1, optStr(r.notes),
        ],
      });
    }
    const groupMap = new Map<number, number>();
    groups.forEach((g, i) => {
      const name = optStr(g.name, 200);
      const oldId = optInt(g.id);
      if (!name || !name.trim() || oldId === null) { skipped++; return; }
      const id = alloc('series_groups');
      groupMap.set(oldId, id);
      stmts.push({
        sql: `INSERT INTO series_groups (id, library_id, name, group_type, description, position)
              VALUES (?, ?, ?, ?, ?, ?)`,
        args: [
          id, libraryFor(g.library_id), name.trim(), optStr(g.group_type, 100) || 'Series Group',
          optStr(g.description), optInt(g.position) ?? i,
        ],
      });
    });
    for (const it of groupItems) {
      const gid = groupMap.get(optInt(it.group_id) ?? -1);
      const sid = seriesMap.get(optInt(it.series_id) ?? -1);
      if (!gid || !sid) { skipped++; continue; }
      stmts.push({
        sql: `INSERT OR IGNORE INTO series_group_items (group_id, series_id, group_role, position)
              VALUES (?, ?, ?, ?)`,
        args: [gid, sid, optStr(it.group_role, 100) || 'Main Story', optInt(it.position) ?? 0],
      });
    }
    statusesIn.forEach((st, i) => {
      const name = optStr(st.name, 100);
      if (!name || !name.trim()) return;
      stmts.push({
        sql: `INSERT OR IGNORE INTO reading_statuses (owner_id, name, color, position)
              VALUES (?, ?, ?, (SELECT COALESCE(MAX(position), -1) + 1 FROM reading_statuses WHERE owner_id = ?))`,
        args: [u, name.trim(), color(st.color) ?? '#B9BEC7', u],
      });
    });

    // Libraries go first so a failure later can be undone by deleting them
    // (which cascades to everything created under them).
    try {
      if (libStmts.length) await ctx.db.transaction(libStmts);
      const CHUNK = 800;
      for (let i = 0; i < stmts.length; i += CHUNK) {
        await ctx.db.transaction(stmts.slice(i, i + CHUNK));
      }
    } catch (err) {
      for (const id of newLibIds) {
        await ops['libraries.delete']({ ...ctx, a: { id } }).catch(() => {});
      }
      throw err;
    }
    return { libraries: newLibIds.length, series: seriesMap.size, skipped };
  },

  // One request for everything the app needs before first paint. The three
  // lookups run concurrently, so sign-in costs one Worker round trip instead
  // of three (each of which can land on a cold Worker instance).
  async 'app.bootstrap'(ctx) {
    const [libraries, statuses, settings] = await Promise.all([
      ops['libraries.getAll'](ctx) as Promise<{ rows: unknown[] }>,
      ops['statuses.getAll'](ctx) as Promise<{ rows: unknown[] }>,
      ops['settings.getAll'](ctx) as Promise<{ rows: unknown[] }>,
    ]);
    return { libraries: libraries.rows, statuses: statuses.rows, settings: settings.rows };
  },

  async 'settings.getAll'(ctx) {
    const r = await ctx.db.execute('SELECT key, value FROM app_settings WHERE owner_id = ?', [ctx.userId]);
    return { rows: r.rows };
  },

  async 'settings.set'(ctx) {
    const key = str(ctx.a.key, 'key', 100);
    if (!ALLOWED_SETTING_KEYS.has(key)) throw bad(`Unknown setting key: ${key}`);
    const value = String(ctx.a.value ?? '');
    if (value.length > 200) throw bad('Setting value too long');
    await ctx.db.execute(
      `INSERT INTO app_settings (owner_id, key, value) VALUES (?, ?, ?)
       ON CONFLICT(owner_id, key) DO UPDATE SET value = excluded.value`,
      [ctx.userId, key, value]
    );
    return { success: true };
  },
};

// ─── Helpers that need `ops` / hoisting ──────────────────────────────

async function requireRelationship(ctx: Ctx, id: number): Promise<void> {
  const r = await ctx.db.execute(
    `SELECT r.id FROM relationships r
     JOIN characters c ON c.id = r.from_character_id
     WHERE r.id = ? AND c.series_id IN (${OWNED_SERIES})`,
    [id, ctx.userId]
  );
  if (r.rows.length === 0) throw notFound('Relationship not found');
}

/** Validates `items: [{seriesId, role}]` and proves every title is the caller's. */
async function groupMembers(ctx: Ctx): Promise<Array<{ seriesId: number; role: string }>> {
  const raw = ctx.a.items ?? [];
  if (!Array.isArray(raw) || raw.length > 500) throw bad('Invalid items');
  const members = raw.map((i: any) => ({
    seriesId: int(i?.seriesId, 'seriesId'),
    role: optStr(i?.role, 100) || 'Main Story',
  }));
  for (const m of members) await requireSeries(ctx, m.seriesId);
  return members;
}

async function replaceGroupItems(ctx: Ctx, groupId: number, members: Array<{ seriesId: number; role: string }>) {
  await ctx.db.transaction([
    { sql: 'DELETE FROM series_group_items WHERE group_id = ?', args: [groupId] },
    ...members.map((m, i) => ({
      sql: 'INSERT OR IGNORE INTO series_group_items (group_id, series_id, group_role, position) VALUES (?, ?, ?, ?)',
      args: [groupId, m.seriesId, m.role, i],
    })),
  ]);
}

// ─── Router ──────────────────────────────────────────────────────────

export const rpcRouter = new Hono<{ Bindings: Env; Variables: Variables }>();

rpcRouter.post('/:op', async (c) => {
  const auth = await AuthUtil.authenticateRequest(c.req.header('Authorization'), c.env.JWT_SECRET);
  if (!auth) return c.json({ error: 'Unauthorized or token expired' }, 401);

  const op = c.req.param('op');
  if (!Object.prototype.hasOwnProperty.call(ops, op)) return c.json({ error: 'Unknown operation' }, 404);

  let a: Args = {};
  try {
    const text = await c.req.text();
    if (text.length > (op === 'data.import' ? 12_000_000 : 1_000_000)) return c.json({ error: 'Request too large' }, 413);
    a = text ? JSON.parse(text) : {};
    if (a === null || typeof a !== 'object' || Array.isArray(a)) throw new Error('bad body');
  } catch {
    return c.json({ error: 'Invalid JSON body' }, 400);
  }

  try {
    const db = new TursoClient(c.env);
    await ensureSchema(db);
    const result = await ops[op]({ db, env: c.env, userId: auth.sub, a });
    return c.json(result ?? { success: true });
  } catch (err) {
    if (err instanceof HttpError) return c.json({ error: err.message }, err.status as 400 | 404);
    console.error(`rpc ${op} failed:`, err);
    return c.json({ error: 'Operation failed' }, 500);
  }
});
