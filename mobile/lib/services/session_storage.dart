import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper around [FlutterSecureStorage] that stores exactly one key:
/// the JWT access token.  All auth screens go through this instead of
/// calling secure-storage directly, keeping the key string in one place.
class SessionStorage {
  static const _tokenKey = 'jwt_token';

  final FlutterSecureStorage _storage;

  const SessionStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> writeToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<void> deleteToken() => _storage.delete(key: _tokenKey);
}
