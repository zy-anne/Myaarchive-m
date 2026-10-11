/// Turso HTTP client — proxied through the Myaarchive Cloudflare Worker.
///
/// Instead of talking directly to the Turso Hrana API (which would require
/// shipping the database auth token in the binary), all queries are sent to
/// the Worker's `/api/db/pipeline` endpoint. The Worker authenticates the
/// caller via their session JWT, then forwards the pipeline to Turso using
/// the server-side-only auth token.
library;
import 'package:dio/dio.dart';

/// Result of a single SQL execute call.
class TursoResult {
  final List<Map<String, dynamic>> rows;
  final int? lastInsertRowid;
  final int affectedRows;

  const TursoResult({
    required this.rows,
    this.lastInsertRowid,
    this.affectedRows = 0,
  });
}

/// Lightweight HTTP client that routes Hrana v2 pipeline requests through the
/// Cloudflare Worker proxy.
class TursoClient {
  final String _workerBaseUrl;
  String sessionToken;
  late final Dio _dio;

  TursoClient({
    required String workerBaseUrl,
    this.sessionToken = '',
  })  : _workerBaseUrl = workerBaseUrl.endsWith('/')
            ? workerBaseUrl.substring(0, workerBaseUrl.length - 1)
            : workerBaseUrl {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));
  }

  /// Update the session token (called after sign-in / sign-up).
  void setSessionToken(String token) {
    sessionToken = token;
  }

  /// Execute a single SQL statement.
  Future<TursoResult> execute(String sql, [List<dynamic>? args]) async {
    final response = await _pipeline([
      _makeExecuteRequest(sql, args ?? []),
      {'type': 'close'},
    ]);
    return _parseResult(response);
  }

  /// Execute multiple statements in a batch (implicit transaction).
  Future<List<TursoResult>> batch(List<MapEntry<String, List<dynamic>>> statements) async {
    final requests = <Map<String, dynamic>>[];
    for (final stmt in statements) {
      requests.add(_makeExecuteRequest(stmt.key, stmt.value));
    }
    requests.add({'type': 'close'});

    final response = await _pipeline(requests);
    final results = <TursoResult>[];
    final responseResults = response.data?['results'] as List? ?? [];
    for (final r in responseResults) {
      if (r['type'] == 'ok' && r['response']?['type'] == 'execute') {
        results.add(_parseExecuteResponse(r['response']['result']));
      }
    }
    return results;
  }

  Future<Response> _pipeline(List<Map<String, dynamic>> requests) async {
    return _dio.post(
      '$_workerBaseUrl/api/db/pipeline',
      data: {'requests': requests},
      options: Options(
        headers: {
          if (sessionToken.isNotEmpty)
            'Authorization': 'Bearer $sessionToken',
          'Content-Type': 'application/json',
        },
      ),
    );
  }

  Map<String, dynamic> _makeExecuteRequest(String sql, List<dynamic> args) {
    return {
      'type': 'execute',
      'stmt': {
        'sql': sql,
        'args': args.map(_encodeArg).toList(),
      },
    };
  }

  Map<String, dynamic> _encodeArg(dynamic value) {
    if (value == null) return {'type': 'null'};
    if (value is int) return {'type': 'integer', 'value': value.toString()};
    if (value is double) return {'type': 'float', 'value': value};
    if (value is String) return {'type': 'text', 'value': value};
    // Fallback: stringify
    return {'type': 'text', 'value': value.toString()};
  }

  TursoResult _parseResult(Response response) {
    final data = response.data;
    final results = (data['results'] as List?) ?? [];
    for (final r in results) {
      if (r['type'] == 'ok' && r['response']?['type'] == 'execute') {
        return _parseExecuteResponse(r['response']['result']);
      }
      if (r['type'] == 'error') {
        final err = r['error'];
        throw TursoException(err?['message'] ?? 'Unknown Turso error');
      }
    }
    return const TursoResult(rows: []);
  }

  TursoResult _parseExecuteResponse(Map<String, dynamic> result) {
    final cols = (result['cols'] as List?)
            ?.map((c) => c['name'] as String)
            .toList() ??
        [];
    final rawRows = (result['rows'] as List?) ?? [];
    final rows = <Map<String, dynamic>>[];

    for (final rawRow in rawRows) {
      final row = <String, dynamic>{};
      final cells = rawRow as List;
      for (int i = 0; i < cols.length && i < cells.length; i++) {
        row[cols[i]] = _decodeValue(cells[i]);
      }
      rows.add(row);
    }

    final affectedRows = result['affected_row_count'] as int? ?? 0;
    final lastId = result['last_insert_rowid'];

    return TursoResult(
      rows: rows,
      lastInsertRowid: lastId != null ? int.tryParse(lastId.toString()) : null,
      affectedRows: affectedRows,
    );
  }

  dynamic _decodeValue(dynamic cell) {
    if (cell == null) return null;
    if (cell is Map) {
      final type = cell['type'];
      final value = cell['value'];
      if (type == 'null') return null;
      if (type == 'integer') return int.tryParse(value.toString()) ?? 0;
      if (type == 'float') {
        return value is num ? value.toDouble() : double.tryParse(value.toString()) ?? 0.0;
      }
      if (type == 'text') return value as String;
      if (type == 'blob') return value; // base64 encoded
      return value;
    }
    return cell;
  }

  void dispose() {
    _dio.close();
  }
}

class TursoException implements Exception {
  final String message;
  const TursoException(this.message);

  @override
  String toString() => 'TursoException: $message';
}
