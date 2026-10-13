-- Migration 001: Initial baseline schema & genres seed

CREATE TABLE IF NOT EXISTS schema_version (
  version INTEGER PRIMARY KEY,
  applied_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  username TEXT UNIQUE NOT NULL COLLATE NOCASE,
  password_hash TEXT NOT NULL,
  security_question TEXT,
  security_answer_hash TEXT,
  created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS libraries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  owner_id TEXT NOT NULL,
  name TEXT NOT NULL,
  icon TEXT DEFAULT 'grid',
  icon_image TEXT,
  position INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS app_settings (
  owner_id TEXT NOT NULL,
  key TEXT NOT NULL,
  value TEXT,
  UNIQUE(owner_id, key)
);

CREATE TABLE IF NOT EXISTS genres (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT UNIQUE NOT NULL COLLATE NOCASE,
  color TEXT DEFAULT '#b2bec3'
);

CREATE TABLE IF NOT EXISTS tags (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  owner_id TEXT NOT NULL,
  name TEXT NOT NULL COLLATE NOCASE,
  color TEXT DEFAULT '#4a90e2',
  UNIQUE(owner_id, name)
);

CREATE TABLE IF NOT EXISTS reading_statuses (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  owner_id TEXT NOT NULL,
  name TEXT NOT NULL,
  color TEXT DEFAULT '#B9BEC7',
  position INTEGER NOT NULL DEFAULT 0,
  UNIQUE(owner_id, name)
);

CREATE TABLE IF NOT EXISTS series (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  author TEXT,
  status TEXT DEFAULT 'Planning',
  synopsis TEXT,
  library_id INTEGER NOT NULL,
  kind TEXT DEFAULT 'series',
  overall_thoughts TEXT,
  chapter_thoughts TEXT,
  cover_image_path TEXT,
  created_at TEXT DEFAULT (datetime('now')),
  book_type TEXT,
  rating INTEGER,
  original_language TEXT,
  country_of_origin TEXT,
  language_read TEXT DEFAULT 'English',
  artist TEXT,
  year_published TEXT,
  date_started TEXT,
  date_finished TEXT,
  status_country_of_origin TEXT,
  licensed_english TEXT,
  completely_translated TEXT,
  original_publisher TEXT,
  english_publisher TEXT,
  is_nsfw INTEGER NOT NULL DEFAULT 0,
  standalone_chapter_count INTEGER,
  fandom TEXT
);

CREATE TABLE IF NOT EXISTS volumes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  series_id INTEGER NOT NULL,
  volume_number INTEGER NOT NULL,
  title TEXT,
  chapter_range TEXT,
  chapter_count INTEGER,
  thoughts TEXT,
  chapter_notes TEXT,
  cover_image_path TEXT,
  date_read TEXT,
  published_date TEXT
);

CREATE TABLE IF NOT EXISTS characters (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  series_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  role TEXT DEFAULT 'Side',
  volume_appearances TEXT,
  notes TEXT,
  profile_image_path TEXT,
  status_role TEXT,
  overall_vibes TEXT,
  appears_vs_reality TEXT,
  appears_text TEXT,
  reality_text TEXT,
  personality TEXT,
  age TEXT,
  life_status TEXT
);

CREATE TABLE IF NOT EXISTS relationships (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  from_character_id INTEGER NOT NULL,
  to_character_id INTEGER NOT NULL,
  type TEXT DEFAULT 'Friend',
  label TEXT,
  is_bidirectional INTEGER DEFAULT 1,
  notes TEXT
);

CREATE TABLE IF NOT EXISTS series_tags (
  series_id INTEGER NOT NULL,
  tag_id INTEGER NOT NULL,
  PRIMARY KEY (series_id, tag_id)
);

CREATE TABLE IF NOT EXISTS series_genres (
  series_id INTEGER NOT NULL,
  genre_id INTEGER NOT NULL,
  PRIMARY KEY (series_id, genre_id)
);

CREATE TABLE IF NOT EXISTS content_warnings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  owner_id TEXT NOT NULL,
  name TEXT NOT NULL COLLATE NOCASE,
  color TEXT DEFAULT '#e17055',
  UNIQUE(owner_id, name)
);

CREATE TABLE IF NOT EXISTS series_content_warnings (
  series_id INTEGER NOT NULL,
  warning_id INTEGER NOT NULL,
  PRIMARY KEY (series_id, warning_id)
);

CREATE TABLE IF NOT EXISTS gallery_images (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  series_id INTEGER NOT NULL,
  image_path TEXT NOT NULL,
  caption TEXT,
  position INTEGER DEFAULT 0,
  created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS link_attachments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  series_id INTEGER NOT NULL,
  url TEXT NOT NULL,
  label TEXT,
  created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS attachments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  series_id INTEGER NOT NULL,
  file_path TEXT NOT NULL,
  file_name TEXT NOT NULL,
  file_size INTEGER,
  created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS glossary_terms (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  series_id INTEGER NOT NULL,
  term TEXT NOT NULL,
  definition TEXT
);

CREATE TABLE IF NOT EXISTS series_groups (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  library_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  group_type TEXT DEFAULT 'Series Group',
  description TEXT,
  position INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS series_group_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  group_id INTEGER NOT NULL,
  series_id INTEGER NOT NULL,
  group_role TEXT DEFAULT 'Main Story',
  position INTEGER NOT NULL DEFAULT 0,
  UNIQUE(group_id, series_id)
);

-- Seed baseline genres
INSERT OR IGNORE INTO genres (name, color) VALUES
  ('Action', '#e74c3c'),
  ('Adventure', '#e67e22'),
  ('Comedy', '#f1c40f'),
  ('Drama', '#9b59b6'),
  ('Fantasy', '#3498db'),
  ('Romance', '#e91e63'),
  ('Sci-Fi', '#00bcd4'),
  ('Slice of Life', '#2ecc71'),
  ('Mystery', '#34495e'),
  ('Horror', '#7f8c8d'),
  ('Supernatural', '#8e44ad'),
  ('Historical', '#d35400'),
  ('Psychological', '#16a085'),
  ('Thriller', '#c0392b'),
  ('Mecha', '#795548'),
  ('Sports', '#27ae60'),
  ('Music', '#ff4081'),
  ('Isekai', '#009688'),
  ('Magic', '#673ab7'),
  ('Mythology', '#ff9800');
