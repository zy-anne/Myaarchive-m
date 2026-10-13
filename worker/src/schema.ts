import { TursoClient } from './db';

/**
 * Versioned schema migrations, applied by the Worker (never by clients).
 *
 * Each migration runs once, in order, inside the `schema_migrations` ledger.
 * Add new migrations to the END of MIGRATIONS and never edit an applied one.
 * Migration 1 is the baseline: it is written to be safe on a database that
 * already has every table and column (the production state before this
 * ledger existed).
 */

type Migration = {
  version: number;
  name: string;
  up: (db: TursoClient) => Promise<void>;
};

const BASELINE_TABLES = [
    `CREATE TABLE IF NOT EXISTS libraries (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      owner_id TEXT NOT NULL,
      name TEXT NOT NULL,
      icon TEXT DEFAULT 'grid',
      icon_image TEXT,
      position INTEGER NOT NULL DEFAULT 0
      )`,
    `CREATE TABLE IF NOT EXISTS app_settings (
      owner_id TEXT NOT NULL,
      key TEXT NOT NULL,
      value TEXT,
      UNIQUE(owner_id, key)
      )`,
    `CREATE TABLE IF NOT EXISTS genres (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT UNIQUE NOT NULL COLLATE NOCASE,
      color TEXT DEFAULT '#b2bec3'
      )`,
    `CREATE TABLE IF NOT EXISTS tags (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      owner_id TEXT NOT NULL,
      name TEXT NOT NULL COLLATE NOCASE,
      color TEXT DEFAULT '#4a90e2',
      UNIQUE(owner_id, name)
      )`,
    `CREATE TABLE IF NOT EXISTS reading_statuses (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      owner_id TEXT NOT NULL,
      name TEXT NOT NULL,
      color TEXT DEFAULT '#B9BEC7',
      position INTEGER NOT NULL DEFAULT 0,
      UNIQUE(owner_id, name)
      )`,
    `CREATE TABLE IF NOT EXISTS series (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      author TEXT,
      status TEXT DEFAULT 'Planning',
      synopsis TEXT,
      library_id INTEGER NOT NULL,
      kind TEXT DEFAULT 'series',
      overall_thoughts TEXT,
      chapter_thoughts TEXT,
      cover_image_path TEXT
      )`,
    `CREATE TABLE IF NOT EXISTS volumes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      series_id INTEGER NOT NULL,
      volume_number INTEGER NOT NULL,
      title TEXT,
      chapter_range TEXT,
      chapter_count INTEGER,
      thoughts TEXT,
      chapter_notes TEXT,
      cover_image_path TEXT,
      date_read TEXT
      )`,
    `CREATE TABLE IF NOT EXISTS characters (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      series_id INTEGER NOT NULL,
      name TEXT NOT NULL,
      role TEXT DEFAULT 'Side',
      volume_appearances TEXT,
      notes TEXT,
      profile_image_path TEXT
      )`,
    `CREATE TABLE IF NOT EXISTS relationships (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      from_character_id INTEGER NOT NULL,
      to_character_id INTEGER NOT NULL,
      type TEXT DEFAULT 'Friend',
      label TEXT,
      is_bidirectional INTEGER DEFAULT 1,
      notes TEXT
      )`,
    `CREATE TABLE IF NOT EXISTS series_tags (
      series_id INTEGER NOT NULL,
      tag_id INTEGER NOT NULL,
      UNIQUE(series_id, tag_id)
      )`,
    `CREATE TABLE IF NOT EXISTS series_genres (
      series_id INTEGER NOT NULL,
      genre_id INTEGER NOT NULL,
      UNIQUE(series_id, genre_id)
      )`,
    `CREATE TABLE IF NOT EXISTS content_warnings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      owner_id TEXT NOT NULL,
      name TEXT NOT NULL COLLATE NOCASE,
      UNIQUE(owner_id, name)
      )`,
    `CREATE TABLE IF NOT EXISTS series_content_warnings (
      series_id INTEGER NOT NULL,
      warning_id INTEGER NOT NULL,
      UNIQUE(series_id, warning_id)
      )`,
    `CREATE TABLE IF NOT EXISTS gallery_images (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      series_id INTEGER NOT NULL,
      image_path TEXT NOT NULL,
      caption TEXT,
      position INTEGER NOT NULL DEFAULT 0
      )`,
    `CREATE TABLE IF NOT EXISTS link_attachments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      series_id INTEGER NOT NULL,
      url TEXT NOT NULL,
      label TEXT,
      created_at TEXT DEFAULT (datetime('now'))
      )`,
    `CREATE TABLE IF NOT EXISTS attachments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      series_id INTEGER NOT NULL,
      file_path TEXT NOT NULL,
      file_name TEXT NOT NULL,
      file_size INTEGER,
      created_at TEXT DEFAULT (datetime('now'))
      )`,
    `CREATE TABLE IF NOT EXISTS glossary_terms (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      series_id INTEGER NOT NULL,
      term TEXT NOT NULL,
      definition TEXT
      )`,
    `CREATE TABLE IF NOT EXISTS series_groups (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      library_id INTEGER NOT NULL,
      name TEXT NOT NULL,
      group_type TEXT DEFAULT 'Series Group',
      description TEXT,
      position INTEGER NOT NULL DEFAULT 0
      )`,
    `CREATE TABLE IF NOT EXISTS series_group_items (
      group_id INTEGER NOT NULL,
      series_id INTEGER NOT NULL,
      group_role TEXT DEFAULT 'Main Story',
      position INTEGER NOT NULL DEFAULT 0,
      UNIQUE(group_id, series_id)
      )`,
];

/** Columns that were added after the first release, per table. */
const BASELINE_COLUMNS: Record<string, Array<[string, string]>> = {
  series: [
    ['book_type', 'TEXT'],
    ['rating', 'INTEGER'],
    ['original_language', 'TEXT'],
    ['country_of_origin', 'TEXT'],
    ['language_read', "TEXT DEFAULT 'English'"],
    ['artist', 'TEXT'],
    ['year_published', 'TEXT'],
    ['date_started', 'TEXT'],
    ['date_finished', 'TEXT'],
    ['status_country_of_origin', 'TEXT'],
    ['licensed_english', 'TEXT'],
    ['completely_translated', 'TEXT'],
    ['original_publisher', 'TEXT'],
    ['english_publisher', 'TEXT'],
    ['is_nsfw', 'INTEGER NOT NULL DEFAULT 0'],
    ['standalone_chapter_count', 'INTEGER'],
    ['fandom', 'TEXT'],
  ],
  volumes: [['published_date', 'TEXT']],
  characters: [
    ['status_role', 'TEXT'],
    ['overall_vibes', 'TEXT'],
    ['appears_vs_reality', 'TEXT'],
    ['appears_text', 'TEXT'],
    ['reality_text', 'TEXT'],
    ['personality', 'TEXT'],
    ['age', 'TEXT'],
    ['life_status', 'TEXT'],
  ],
  series_groups: [
    ['group_type', "TEXT DEFAULT 'Series Group'"],
    ['description', 'TEXT'],
    ['position', 'INTEGER NOT NULL DEFAULT 0'],
  ],
  series_group_items: [
    ['group_role', "TEXT DEFAULT 'Main Story'"],
    ['position', 'INTEGER NOT NULL DEFAULT 0'],
  ],
};

async function addMissingColumns(db: TursoClient): Promise<void> {
  for (const [table, cols] of Object.entries(BASELINE_COLUMNS)) {
    const info = await db.execute(`PRAGMA table_info(${table})`);
    const have = new Set(info.rows.map((r) => String(r.name)));
    for (const [name, type] of cols) {
      if (!have.has(name)) await db.execute(`ALTER TABLE ${table} ADD COLUMN ${name} ${type}`);
    }
  }
}

const MIGRATIONS: Migration[] = [
  {
    version: 1,
    name: 'baseline schema',
    async up(db) {
      await db.batch(BASELINE_TABLES.map((sql) => ({ sql })));
      await addMissingColumns(db);
    },
  },
  {
    version: 2,
    name: 'indexes for owner-scoped lookups',
    async up(db) {
      await db.batch([
        { sql: 'CREATE INDEX IF NOT EXISTS idx_series_library ON series(library_id)' },
        { sql: 'CREATE INDEX IF NOT EXISTS idx_volumes_series ON volumes(series_id)' },
        { sql: 'CREATE INDEX IF NOT EXISTS idx_characters_series ON characters(series_id)' },
        { sql: 'CREATE INDEX IF NOT EXISTS idx_gallery_series ON gallery_images(series_id)' },
        { sql: 'CREATE INDEX IF NOT EXISTS idx_links_series ON link_attachments(series_id)' },
        { sql: 'CREATE INDEX IF NOT EXISTS idx_attachments_series ON attachments(series_id)' },
        { sql: 'CREATE INDEX IF NOT EXISTS idx_glossary_series ON glossary_terms(series_id)' },
        { sql: 'CREATE INDEX IF NOT EXISTS idx_rel_from ON relationships(from_character_id)' },
        { sql: 'CREATE INDEX IF NOT EXISTS idx_rel_to ON relationships(to_character_id)' },
        { sql: 'CREATE INDEX IF NOT EXISTS idx_libraries_owner ON libraries(owner_id)' },
        { sql: 'CREATE INDEX IF NOT EXISTS idx_sgi_group ON series_group_items(group_id)' },
        { sql: 'CREATE INDEX IF NOT EXISTS idx_sgi_series ON series_group_items(series_id)' },
      ]);
    },
  },
];

let ensured: Promise<void> | null = null;

/** Applies pending migrations once per Worker isolate. */
export function ensureSchema(db: TursoClient): Promise<void> {
  if (!ensured) {
    ensured = runMigrations(db).catch((err) => {
      ensured = null; // retry on the next request
      throw err;
    });
  }
  return ensured;
}

async function runMigrations(db: TursoClient): Promise<void> {
  await db.execute(
    `CREATE TABLE IF NOT EXISTS schema_migrations (
       version INTEGER PRIMARY KEY,
       name TEXT NOT NULL,
       applied_at TEXT NOT NULL DEFAULT (datetime('now'))
     )`
  );
  const done = await db.execute('SELECT MAX(version) AS v FROM schema_migrations');
  const current = Number(done.rows[0]?.v ?? 0);
  for (const m of MIGRATIONS) {
    if (m.version <= current) continue;
    await m.up(db);
    await db.execute('INSERT INTO schema_migrations (version, name) VALUES (?, ?)', [m.version, m.name]);
  }
}
