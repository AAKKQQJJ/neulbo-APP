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
  final List<String>? imageUrls; // 게시글 이미지 URL 목록
  final DateTime createdAt;
  final DateTime updatedAt;
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
  final List<Comment> comments;

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
    this.imageUrls,
    required this.createdAt,
    required this.updatedAt,
    required this.viewCount,
    required this.likeCount,
    required this.commentCount,
    this.isLiked = false,
    this.comments = const [],
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
      imageUrls: json['imageUrls'] != null 
          ? List<String>.from(json['imageUrls'] as List)
          : null,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
      viewCount: json['viewCount'] as int,
      likeCount: json['likeCount'] as int,
      commentCount: json['commentCount'] as int,
      isLiked: json['isLiked'] as bool? ?? false,
      comments: json['comments'] != null
          ? List<Comment>.from(
              (json['comments'] as List).map((x) => Comment.fromJson(x)))
          : const [],
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
      'imageUrls': imageUrls,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'viewCount': viewCount,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'isLiked': isLiked,
      'comments': comments.map((x) => x.toJson()).toList(),
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

  Comment copyWith({
    String? commentId,
    String? content,
    String? postId,
    String? authorId,
    String? authorNickname,
    String? authorProfileImage,
    String? parentCommentId,
    DateTime? createdAt,
    int? likeCount,
    bool? isLiked,
  }) {
    return Comment(
      commentId: commentId ?? this.commentId,
      content: content ?? this.content,
      postId: postId ?? this.postId,
      authorId: authorId ?? this.authorId,
      authorNickname: authorNickname ?? this.authorNickname,
      authorProfileImage: authorProfileImage ?? this.authorProfileImage,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      createdAt: createdAt ?? this.createdAt,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}

class PostCategory {
  static const String sleepTip = 'sleep_tip';
  static const String question = 'question';
  static const String experience = 'experience';
  static const String challenge = 'challenge';

  static const Map<String, String> categoryNames = {
    sleepTip: '수면 쿨팁',
    question: '잠이 안와요',
    experience: '일상',
    challenge: '챌린지',
  };

  static String getDisplayName(String category) {
    return categoryNames[category] ?? category;
  }
}
