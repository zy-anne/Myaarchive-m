/// Turso HTTP client — speaks the Hrana over HTTP protocol.
///
/// Mirrors what `@libsql/client/http` does in the Electron app's
/// `data-layer/client.js:createRemoteClient()`. Every query goes
/// over the network (no embedded replica on mobile yet), so this
/// should be used with good error handling and loading states.
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

/// Lightweight HTTP client for Turso's Hrana pipeline API.
class TursoClient {
  final String _baseUrl;
  final String _authToken;
  late final Dio _dio;

  TursoClient({required String databaseUrl, required String authToken})
      : _baseUrl = _httpUrl(databaseUrl),
        _authToken = authToken {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));
  }

  /// Convert libsql:// URL → https:// for the HTTP API.
  static String _httpUrl(String url) {
    String base = url
        .replaceFirst('libsql://', 'https://')
        .replaceFirst('wss://', 'https://');
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    return base;
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
      '$_baseUrl/v2/pipeline',
      data: {'requests': requests},
      options: Options(
        headers: {
          'Authorization': 'Bearer $_authToken',
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
