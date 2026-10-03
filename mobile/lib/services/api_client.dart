import 'dart:convert';
import 'package:http/http.dart' as http;

/// Thrown whenever the backend returns a non-2xx status.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Thin wrapper around [http] that:
/// - Prefixes every path with [baseUrl]
/// - Attaches a Bearer token when provided
/// - Returns decoded JSON on 2xx
/// - Throws [ApiException] with the backend's `detail` message on any other
///   status code
class ApiClient {
  // ── Base URL ─────────────────────────────────────────────────────────────
  // For the Android emulator use 10.0.2.2 (which maps to the host machine's
  // loopback). For iOS simulator use localhost. Swap to your server address
  // for a real device or production build.
  static const String baseUrl = 'http://10.0.2.2:8000';

  String? _token;

  /// Update the stored Bearer token (call after login/verify-otp).
  void setToken(String? token) => _token = token;

  // ── Internal helpers ──────────────────────────────────────────────────────

  Map<String, String> _headers({bool auth = false}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    String message;
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      message = body['detail']?.toString() ?? 'Unknown error';
    } catch (_) {
      message = response.reasonPhrase ?? 'Unknown error';
    }
    throw ApiException(statusCode: response.statusCode, message: message);
  }

  // ── Public methods ────────────────────────────────────────────────────────

  Future<dynamic> get(String path, {bool auth = false}) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await http.get(uri, headers: _headers(auth: auth));
    return _handleResponse(response);
  }

  Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await http.post(
      uri,
      headers: _headers(auth: auth),
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  Future<dynamic> put(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await http.put(
      uri,
      headers: _headers(auth: auth),
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }
}
