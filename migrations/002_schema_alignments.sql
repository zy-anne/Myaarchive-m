-- Migration 002: Schema alignments and table mergers

-- 1. Ensure series table has created_at
-- (SQLite ignores duplicate column errors if handled or checked)
-- 2. Migrate legacy statuses table into reading_statuses if it exists
INSERT OR IGNORE INTO reading_statuses (owner_id, name, color, position)
SELECT owner_id, name, color, position
FROM sqlite_master m, statuses s
WHERE m.type = 'table' AND m.name = 'statuses';

-- 3. Ensure default 5 reading statuses exist for all library owners
INSERT OR IGNORE INTO reading_statuses (owner_id, name, color, position)
SELECT DISTINCT owner_id, 'Reading', '#9B7EDE', 0 FROM libraries;

INSERT OR IGNORE INTO reading_statuses (owner_id, name, color, position)
SELECT DISTINCT owner_id, 'Finished', '#7FC9A0', 1 FROM libraries;

INSERT OR IGNORE INTO reading_statuses (owner_id, name, color, position)
SELECT DISTINCT owner_id, 'On Hold', '#E8C15C', 2 FROM libraries;

INSERT OR IGNORE INTO reading_statuses (owner_id, name, color, position)
SELECT DISTINCT owner_id, 'Planning', '#6FA8DC', 3 FROM libraries;

INSERT OR IGNORE INTO reading_statuses (owner_id, name, color, position)
SELECT DISTINCT owner_id, 'Dropped', '#DD7A6E', 4 FROM libraries;
