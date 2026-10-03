import 'api_client.dart';

/// Wraps all auth-related API calls.
///
/// Each method returns exactly what the screen needs:
/// - [register] → email string on success (for routing to OTP screen)
/// - [resendOtp] → void on success
/// - [verifyOtp] → [AuthResult] on success
/// - [login]     → [AuthResult] on success
///
/// All failures propagate as [ApiException] so screens can show the backend's
/// `detail` message verbatim (section 6 of LLD.md).
class AuthService {
  final ApiClient _api;

  const AuthService(this._api);

  /// POST /auth/register
  /// Returns the confirmed email on 201; throws [ApiException] otherwise.
  Future<String> register({
    required String email,
    required String password,
  }) async {
    final body = await _api.post('/auth/register', {
      'email': email,
      'password': password,
    });
    return (body as Map<String, dynamic>)['email'] as String;
  }

  /// POST /auth/resend-otp
  Future<void> resendOtp({required String email}) async {
    await _api.post('/auth/resend-otp', {'email': email});
  }

  /// POST /auth/verify-otp
  /// Returns an [AuthResult] containing the JWT and profile-complete flag.
  Future<AuthResult> verifyOtp({
    required String email,
    required String code,
  }) async {
    final body = await _api.post('/auth/verify-otp', {
      'email': email,
      'code': code,
    });
    return AuthResult.fromJson(body as Map<String, dynamic>);
  }

  /// POST /auth/login
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final body = await _api.post('/auth/login', {
      'email': email,
      'password': password,
    });
    return AuthResult.fromJson(body as Map<String, dynamic>);
  }
}

/// Holds the token + profile-complete flag returned by verify-otp and login.
class AuthResult {
  final String accessToken;
  final bool hasCompletedProfile;

  const AuthResult({
    required this.accessToken,
    required this.hasCompletedProfile,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
        accessToken: json['access_token'] as String,
        hasCompletedProfile: (json['has_completed_profile'] as bool?) ?? false,
      );
}
