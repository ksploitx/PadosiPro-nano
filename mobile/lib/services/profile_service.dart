import 'api_client.dart';
import '../models/profile.dart';

/// Wraps PUT /profile and GET /profile.
class ProfileService {
  final ApiClient _api;
  const ProfileService(this._api);

  /// PUT /profile — create or update the user's profile.
  /// Returns the saved [UserProfile] on success; throws [ApiException] on error.
  Future<UserProfile> saveProfile(UserProfile profile) async {
    final body = await _api.put(
      '/profile',
      profile.toJson(),
      auth: true,
    );
    return UserProfile.fromJson(body as Map<String, dynamic>);
  }

  /// GET /profile — fetch the user's profile.
  /// Throws [ApiException] with statusCode 404 when no profile exists yet.
  Future<UserProfile> getProfile() async {
    final body = await _api.get('/profile', auth: true);
    return UserProfile.fromJson(body as Map<String, dynamic>);
  }
}
