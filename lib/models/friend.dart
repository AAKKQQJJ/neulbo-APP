class Friend {
  final String friendshipId;
  final FriendUser friend;
  final DateTime friendshipDate;
  final int mutualFriendsCount;

  const Friend({
    required this.friendshipId,
    required this.friend,
    required this.friendshipDate,
    required this.mutualFriendsCount,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      friendshipId: json['friendshipId'] as String,
      friend: FriendUser.fromJson(json['friend'] as Map<String, dynamic>),
      friendshipDate: DateTime.parse(json['friendshipDate'] as String),
      mutualFriendsCount: json['mutualFriendsCount'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'friendshipId': friendshipId,
      'friend': friend.toJson(),
      'friendshipDate': friendshipDate.toIso8601String(),
      'mutualFriendsCount': mutualFriendsCount,
    };
  }
}

class FriendUser {
  final String userId;
  final String nickname;
  final String? profileImage;
  final bool isOnline;
  final DateTime? lastSeenAt;

  const FriendUser({
    required this.userId,
    required this.nickname,
    this.profileImage,
    this.isOnline = false,
    this.lastSeenAt,
  });

  factory FriendUser.fromJson(Map<String, dynamic> json) {
    return FriendUser(
      userId: json['userId'] as String,
      nickname: json['nickname'] as String,
      profileImage: json['profileImage'] as String?,
      isOnline: json['isOnline'] as bool? ?? false,
      lastSeenAt: json['lastSeenAt'] != null
          ? DateTime.parse(json['lastSeenAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'nickname': nickname,
      'profileImage': profileImage,
      'isOnline': isOnline,
      'lastSeenAt': lastSeenAt?.toIso8601String(),
    };
  }
}

class FriendRequest {
  final String friendRequestId;
  final FriendUser fromUser;
  final FriendUser toUser;
  final String? message;
  final FriendRequestStatus status;
  final DateTime createdAt;
  final DateTime? processedAt;

  const FriendRequest({
    required this.friendRequestId,
    required this.fromUser,
    required this.toUser,
    this.message,
    required this.status,
    required this.createdAt,
    this.processedAt,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      friendRequestId: json['friendRequestId'] as String,
      fromUser: FriendUser.fromJson(json['fromUser'] as Map<String, dynamic>),
      toUser: FriendUser.fromJson(json['toUser'] as Map<String, dynamic>),
      message: json['message'] as String?,
      status: FriendRequestStatus.fromString(json['status'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      processedAt: json['processedAt'] != null
          ? DateTime.parse(json['processedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'friendRequestId': friendRequestId,
      'fromUser': fromUser.toJson(),
      'toUser': toUser.toJson(),
      'message': message,
      'status': status.toString(),
      'createdAt': createdAt.toIso8601String(),
      'processedAt': processedAt?.toIso8601String(),
    };
  }
}

enum FriendRequestStatus {
  pending,
  accepted,
  rejected;

  static FriendRequestStatus fromString(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return FriendRequestStatus.pending;
      case 'ACCEPTED':
        return FriendRequestStatus.accepted;
      case 'REJECTED':
        return FriendRequestStatus.rejected;
      default:
        return FriendRequestStatus.pending;
    }
  }

  @override
  String toString() {
    return name.toUpperCase();
  }
}

enum FriendshipStatus {
  none,
  pendingSent,
  pendingReceived,
  friends;

  static FriendshipStatus fromString(String status) {
    switch (status) {
      case 'NONE':
        return FriendshipStatus.none;
      case 'PENDING_SENT':
        return FriendshipStatus.pendingSent;
      case 'PENDING_RECEIVED':
        return FriendshipStatus.pendingReceived;
      case 'FRIENDS':
        return FriendshipStatus.friends;
      default:
        return FriendshipStatus.none;
    }
  }

  @override
  String toString() {
    switch (this) {
      case FriendshipStatus.none:
        return 'NONE';
      case FriendshipStatus.pendingSent:
        return 'PENDING_SENT';
      case FriendshipStatus.pendingReceived:
        return 'PENDING_RECEIVED';
      case FriendshipStatus.friends:
        return 'FRIENDS';
    }
  }
}

class UserSearchResult {
  final String userId;
  final String nickname;
  final String? profileImage;
  final FriendshipStatus friendshipStatus;
  final int mutualFriendsCount;

  const UserSearchResult({
    required this.userId,
    required this.nickname,
    this.profileImage,
    required this.friendshipStatus,
    required this.mutualFriendsCount,
  });

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      userId: json['userId'] as String,
      nickname: json['nickname'] as String,
      profileImage: json['profileImage'] as String?,
      friendshipStatus: FriendshipStatus.fromString(json['friendshipStatus'] as String),
      mutualFriendsCount: json['mutualFriendsCount'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'nickname': nickname,
      'profileImage': profileImage,
      'friendshipStatus': friendshipStatus.toString(),
      'mutualFriendsCount': mutualFriendsCount,
    };
  }
}
