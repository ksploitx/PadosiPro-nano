/// Data models for the profile feature.
class UserProfile {
  final String name;
  final String mobileNumber;
  final String address;
  final String? businessName;

  const UserProfile({
    required this.name,
    required this.mobileNumber,
    required this.address,
    this.businessName,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        name: json['name'] as String,
        mobileNumber: json['mobile_number'] as String,
        address: json['address'] as String,
        businessName: json['business_name'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'mobile_number': mobileNumber,
        'address': address,
        'business_name': businessName,
      };
}
