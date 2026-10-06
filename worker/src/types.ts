export interface Env {
  BUCKET: R2Bucket;
  TURSO_DB_URL: string;
  TURSO_AUTH_TOKEN: string;
  JWT_SECRET: string;
}

export interface UserSession {
  id: string;
  username: string;
  securityQuestion?: string | null;
  createdAt?: string | null;
}

export interface JwtPayload {
  sub: string; // user ID
  username: string;
  exp: number; // unix seconds
  iat: number; // unix seconds
}

export interface TursoValue {
  type: 'null' | 'integer' | 'float' | 'text' | 'blob';
  value?: string | number | null;
}

export interface TursoStmt {
  sql: string;
  args?: TursoValue[];
}

export interface TursoRequest {
  type: 'execute' | 'close';
  stmt?: TursoStmt;
}

export interface TursoResult {
  cols: Array<{ name: string }>;
  rows: any[][];
  affected_row_count: number;
  last_insert_rowid?: string | number | null;
}
