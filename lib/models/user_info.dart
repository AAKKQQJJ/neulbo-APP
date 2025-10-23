class UserInfo {
  final String? userId; // 백엔드에서 받은 사용자 UUID
  final String provider;
  final String providerId;
  final String email;
  final String name;
  final String profileImageUrl;
  final String nickname;
  final String? accessToken;
  final String? refreshToken;
  final bool isNewUser;

  const UserInfo({
    this.userId,
    required this.provider,
    required this.providerId,
    required this.email,
    required this.name,
    required this.profileImageUrl,
    required this.nickname,
    this.accessToken,
    this.refreshToken,
    this.isNewUser = false,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      userId: json['userId'] as String?,
      provider: json['provider'] as String,
      providerId: json['providerId'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      profileImageUrl: json['profileImageUrl'] as String,
      nickname: json['nickname'] as String,
      accessToken: json['accessToken'] as String?,
      refreshToken: json['refreshToken'] as String?,
      isNewUser: json['isNewUser'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'provider': provider,
      'providerId': providerId,
      'email': email,
      'name': name,
      'profileImageUrl': profileImageUrl,
      'nickname': nickname,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'isNewUser': isNewUser,
    };
  }
}
