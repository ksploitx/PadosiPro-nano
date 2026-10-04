/// Data models for the profile feature.
class UserProfile {
  final String name;
  final String mobileNumber;
  final String address;
  final String? businessName;
  /// Email comes from GET /profile (joined from User row).
  /// May be null when constructed locally for PUT /profile (email is read-only).
  final String? email;

  const UserProfile({
    required this.name,
    required this.mobileNumber,
    required this.address,
    this.businessName,
    this.email,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        name: json['name'] as String,
        mobileNumber: json['mobile_number'] as String,
        address: json['address'] as String,
        businessName: json['business_name'] as String?,
        email: json['email'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'mobile_number': mobileNumber,
        'address': address,
        'business_name': businessName,
        // email is NOT sent in PUT /profile — it's auth-managed
      };
}
