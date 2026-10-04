import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_client.dart';

/// Shared application state exposed via [ChangeNotifier].
///
/// Screens read from this (via context.watch<AppState>()) and call mutators
/// to update it. [bootstrap()] is called once at startup to restore a
/// persisted JWT from secure storage.
class AppState extends ChangeNotifier {
  // ── Dependencies ──────────────────────────────────────────────────────────
  final ApiClient apiClient;
  final FlutterSecureStorage _storage;

  AppState({
    required this.apiClient,
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  // ── State ─────────────────────────────────────────────────────────────────
  static const _tokenKey = 'jwt_token';
  static const _emailKey = 'user_email';

  String? _token;
  String? _email;
  bool _hasCompletedProfile = false;
  bool _bootstrapped = false;

  // ── Getters ───────────────────────────────────────────────────────────────
  String? get token => _token;
  String? get email => _email;
  bool get isLoggedIn => _token != null;
  bool get hasCompletedProfile => _hasCompletedProfile;

  /// True once [bootstrap()] has finished. The root widget uses this to decide
  /// whether to show a splash/loading view or route the user to the right
  /// screen.
  bool get bootstrapped => _bootstrapped;

  // ── Bootstrap ─────────────────────────────────────────────────────────────

  /// Reads a persisted JWT from secure storage. If found, attaches it to
  /// [apiClient] so every subsequent call is authenticated.
  ///
  /// Does NOT hit the network — we intentionally leave network calls to the
  /// individual screens so they can handle errors with their own UI.
  Future<void> bootstrap() async {
    final stored = await _storage.read(key: _tokenKey);
    if (stored != null) {
      _token = stored;
      apiClient.setToken(stored);
    }
    _email = await _storage.read(key: _emailKey);
    _bootstrapped = true;
    notifyListeners();
  }

  // ── Mutators ──────────────────────────────────────────────────────────────

  /// Called by LoginScreen / VerifyOtpScreen after a successful
  /// authentication response.
  Future<void> saveToken(
    String token, {
    required bool hasCompletedProfile,
    String? email,
  }) async {
    _token = token;
    _hasCompletedProfile = hasCompletedProfile;
    if (email != null) _email = email;
    apiClient.setToken(token);
    await _storage.write(key: _tokenKey, value: token);
    if (email != null) await _storage.write(key: _emailKey, value: email);
    notifyListeners();
  }

  /// Called by ProfileScreen once the user has saved their profile details.
  void markProfileCompleted() {
    _hasCompletedProfile = true;
    notifyListeners();
  }

  /// Clears the session — call on logout.
  Future<void> logout() async {
    _token = null;
    _email = null;
    _hasCompletedProfile = false;
    apiClient.setToken(null);
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _emailKey);
    notifyListeners();
  }
}
