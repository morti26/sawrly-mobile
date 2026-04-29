class CreatorStatus {
  final String id;
  final String creatorId;
  final String creatorName;
  final String creatorImage;
  final bool isOnline;
  final bool hasStory;
  final String? videoUrl;
  final String? imageUrl;
  final String mediaType; // 'image' or 'video'
  final DateTime expiresAt;
  final int likeCount;
  final bool likedByMe;

  CreatorStatus({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    required this.creatorImage,
    required this.isOnline,
    required this.hasStory,
    required this.mediaType,
    required this.expiresAt,
    this.likeCount = 0,
    this.likedByMe = false,
    this.videoUrl,
    this.imageUrl,
  });

  static String _normalizeUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final value = raw.trim();
    if (value.startsWith('/')) {
      return "https://sawrly.com$value";
    }
    if (value.startsWith('http://ph.sitely24.com')) {
      return value.replaceFirst('http://ph.sitely24.com', 'https://sawrly.com');
    }
    if (value.startsWith('http://sawrly.com')) {
      return value.replaceFirst('http://', 'https://');
    }
    return value;
  }

  factory CreatorStatus.fromJson(Map<String, dynamic> json) {
    final mediaType = json['media_type'] ?? 'image';
    final mediaUrl = _normalizeUrl(json['media_url']?.toString());
    final avatarUrl = _normalizeUrl(json['creator_avatar']?.toString());
    final creatorImage = avatarUrl.isNotEmpty
        ? avatarUrl
        : (mediaType == 'image' && mediaUrl.isNotEmpty
            ? mediaUrl
            : "https://via.placeholder.com/150");

    return CreatorStatus(
      id: json['id'],
      creatorId: json['creator_id'],
      creatorName: json['creator_name'],
      creatorImage: creatorImage,
      isOnline: false,
      hasStory: true,
      mediaType: mediaType,
      expiresAt: DateTime.parse(json['expires_at']),
      imageUrl: mediaUrl,
      videoUrl: mediaType == 'video' ? mediaUrl : null,
      likeCount:
          json['like_count'] is num ? (json['like_count'] as num).toInt() : 0,
      likedByMe: json['liked_by_me'] == true,
    );
  }

  CreatorStatus copyWith({
    String? id,
    String? creatorId,
    String? creatorName,
    String? creatorImage,
    bool? isOnline,
    bool? hasStory,
    String? videoUrl,
    String? imageUrl,
    String? mediaType,
    DateTime? expiresAt,
    int? likeCount,
    bool? likedByMe,
  }) {
    return CreatorStatus(
      id: id ?? this.id,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      creatorImage: creatorImage ?? this.creatorImage,
      isOnline: isOnline ?? this.isOnline,
      hasStory: hasStory ?? this.hasStory,
      mediaType: mediaType ?? this.mediaType,
      expiresAt: expiresAt ?? this.expiresAt,
      likeCount: likeCount ?? this.likeCount,
      likedByMe: likedByMe ?? this.likedByMe,
      videoUrl: videoUrl ?? this.videoUrl,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
