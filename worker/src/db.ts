import { Env, TursoRequest, TursoResult, TursoValue } from './types';

export interface ExecuteResult {
  rows: Record<string, any>[];
  lastInsertRowid?: number | null;
  affectedRows: number;
}

export class TursoClient {
  private baseUrl: string;
  private authToken: string;

  constructor(env: Env) {
    let url = env.TURSO_DB_URL || '';
    url = url.replace(/^libsql:\/\//, 'https://').replace(/^wss:\/\//, 'https://');
    if (url.endsWith('/')) url = url.slice(0, -1);
    this.baseUrl = url;
    this.authToken = env.TURSO_AUTH_TOKEN || '';
  }

  static encodeArg(val: any): TursoValue {
    if (val === null || val === undefined) return { type: 'null' };
    if (typeof val === 'number') {
      if (Number.isInteger(val)) {
        return { type: 'integer', value: val.toString() };
      }
      return { type: 'float', value: val };
    }
    if (typeof val === 'boolean') {
      return { type: 'integer', value: val ? '1' : '0' };
    }
    return { type: 'text', value: String(val) };
  }

  static decodeValue(cell: any): any {
    if (cell === null || cell === undefined) return null;
    if (typeof cell === 'object' && 'type' in cell) {
      const type = cell.type;
      const value = cell.value;
      if (type === 'null') return null;
      if (type === 'integer') return parseInt(String(value), 10) || 0;
      if (type === 'float') return typeof value === 'number' ? value : parseFloat(String(value)) || 0.0;
      if (type === 'text') return String(value);
      if (type === 'blob') return value;
      return value;
    }
    return cell;
  }

  static parseResult(result: TursoResult): ExecuteResult {
    const cols = (result.cols || []).map((c) => c.name);
    const rawRows = result.rows || [];
    const rows: Record<string, any>[] = [];

    for (const rawRow of rawRows) {
      const row: Record<string, any> = {};
      for (let i = 0; i < cols.length && i < rawRow.length; i++) {
        row[cols[i]] = TursoClient.decodeValue(rawRow[i]);
      }
      rows.push(row);
    }

    const lastId = result.last_insert_rowid;
    return {
      rows,
      lastInsertRowid: lastId ? parseInt(String(lastId), 10) : null,
      affectedRows: result.affected_row_count || 0,
    };
  }

  private makeExecuteRequest(sql: string, args: any[] = []): TursoRequest {
    return {
      type: 'execute',
      stmt: {
        sql,
        args: args.map(TursoClient.encodeArg),
      },
    };
  }

  async pipeline(requests: TursoRequest[]): Promise<any> {
    if (!this.baseUrl || !this.authToken) {
      throw new Error('Turso database URL and auth token must be configured');
    }

    const res = await fetch(`${this.baseUrl}/v2/pipeline`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.authToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ requests }),
    });

    if (!res.ok) {
      const text = await res.text();
      throw new Error(`Turso HTTP error ${res.status}: ${text}`);
    }

    return await res.json();
  }

  async execute(sql: string, args: any[] = []): Promise<ExecuteResult> {
    const response = await this.pipeline([
      this.makeExecuteRequest(sql, args),
      { type: 'close' },
    ]);

    const results = response.results || [];
    for (const r of results) {
      if (r.type === 'ok' && r.response?.type === 'execute') {
        return TursoClient.parseResult(r.response.result);
      }
      if (r.type === 'error') {
        throw new Error(r.error?.message || 'Turso query execution error');
      }
    }
    return { rows: [], affectedRows: 0 };
  }

  async batch(statements: Array<{ sql: string; args?: any[] }>): Promise<ExecuteResult[]> {
    const requests: TursoRequest[] = statements.map((s) =>
      this.makeExecuteRequest(s.sql, s.args || [])
    );
    requests.push({ type: 'close' });

    const response = await this.pipeline(requests);
    const results: ExecuteResult[] = [];
    const responseResults = response.results || [];

    for (const r of responseResults) {
      if (r.type === 'ok' && r.response?.type === 'execute') {
        results.push(TursoClient.parseResult(r.response.result));
      } else if (r.type === 'error') {
        throw new Error(r.error?.message || 'Turso batch execution error');
      }
    }
    return results;
  }

  async transaction(statements: Array<{ sql: string; args?: any[] }>): Promise<ExecuteResult[]> {
    const txStatements = [
      { sql: 'BEGIN TRANSACTION', args: [] },
      ...statements,
      { sql: 'COMMIT', args: [] },
    ];
    const results = await this.batch(txStatements);
    // Exclude BEGIN and COMMIT results
    return results.slice(1, -1);
  }
}
