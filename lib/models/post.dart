class Post {
  final String postId;
  final String title;
  final String content;
  final String category;
  final List<String> tags;
  final bool isPublic;
  final String authorId;
  final String authorNickname;
  final String? authorProfileImage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
  final List<Comment>? comments;

  const Post({
    required this.postId,
    required this.title,
    required this.content,
    required this.category,
    required this.tags,
    required this.isPublic,
    required this.authorId,
    required this.authorNickname,
    this.authorProfileImage,
    required this.createdAt,
    required this.updatedAt,
    required this.viewCount,
    required this.likeCount,
    required this.commentCount,
    this.isLiked = false,
    this.comments,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      postId: json['postId'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      category: json['category'] as String,
      tags: List<String>.from(json['tags'] as List),
      isPublic: json['isPublic'] as bool,
      authorId: json['authorId'] as String,
      authorNickname: json['authorNickname'] as String,
      authorProfileImage: json['authorProfileImage'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      viewCount: json['viewCount'] as int,
      likeCount: json['likeCount'] as int,
      commentCount: json['commentCount'] as int,
      isLiked: json['isLiked'] as bool? ?? false,
      comments: json['comments'] != null
          ? List<Comment>.from(
              (json['comments'] as List).map((x) => Comment.fromJson(x)))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'postId': postId,
      'title': title,
      'content': content,
      'category': category,
      'tags': tags,
      'isPublic': isPublic,
      'authorId': authorId,
      'authorNickname': authorNickname,
      'authorProfileImage': authorProfileImage,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'viewCount': viewCount,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'isLiked': isLiked,
      'comments': comments?.map((x) => x.toJson()).toList(),
    };
  }

  Post copyWith({
    String? postId,
    String? title,
    String? content,
    String? category,
    List<String>? tags,
    bool? isPublic,
    String? authorId,
    String? authorNickname,
    String? authorProfileImage,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? viewCount,
    int? likeCount,
    int? commentCount,
    bool? isLiked,
    List<Comment>? comments,
  }) {
    return Post(
      postId: postId ?? this.postId,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      isPublic: isPublic ?? this.isPublic,
      authorId: authorId ?? this.authorId,
      authorNickname: authorNickname ?? this.authorNickname,
      authorProfileImage: authorProfileImage ?? this.authorProfileImage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      viewCount: viewCount ?? this.viewCount,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      isLiked: isLiked ?? this.isLiked,
      comments: comments ?? this.comments,
    );
  }
}

class Comment {
  final String commentId;
  final String content;
  final String postId;
  final String authorId;
  final String authorNickname;
  final String? authorProfileImage;
  final String? parentCommentId;
  final DateTime createdAt;
  final int likeCount;
  final bool isLiked;

  const Comment({
    required this.commentId,
    required this.content,
    required this.postId,
    required this.authorId,
    required this.authorNickname,
    this.authorProfileImage,
    this.parentCommentId,
    required this.createdAt,
    required this.likeCount,
    this.isLiked = false,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      commentId: json['commentId'] as String,
      content: json['content'] as String,
      postId: json['postId'] as String,
      authorId: json['authorId'] as String,
      authorNickname: json['authorNickname'] as String,
      authorProfileImage: json['authorProfileImage'] as String?,
      parentCommentId: json['parentCommentId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      likeCount: json['likeCount'] as int,
      isLiked: json['isLiked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'commentId': commentId,
      'content': content,
      'postId': postId,
      'authorId': authorId,
      'authorNickname': authorNickname,
      'authorProfileImage': authorProfileImage,
      'parentCommentId': parentCommentId,
      'createdAt': createdAt.toIso8601String(),
      'likeCount': likeCount,
      'isLiked': isLiked,
    };
  }
}

class PostCategory {
  static const String friend = 'friend';
  static const String sleepTrouble = 'sleep_trouble';
  static const String sleepTip = 'sleep_tip';
  static const String daily = 'daily';

  static const Map<String, String> categoryNames = {
    friend: '친구',
    sleepTrouble: '잠이 안와요',
    sleepTip: '수면 쿨팁',
    daily: '일상',
  };

  static String getDisplayName(String category) {
    return categoryNames[category] ?? category;
  }
}
