import 'offer.dart' show normalizePublicMediaUrl;

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
  final DateTime createdAt;
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
    required this.createdAt,
    required this.expiresAt,
    this.likeCount = 0,
    this.likedByMe = false,
    this.videoUrl,
    this.imageUrl,
  });

  factory CreatorStatus.fromJson(Map<String, dynamic> json) {
    final mediaType = json['media_type'] ?? 'image';
    final mediaUrl =
        normalizePublicMediaUrl(json['media_url']?.toString() ?? '');
    final avatarUrl =
        normalizePublicMediaUrl(json['creator_avatar']?.toString() ?? '');
    final creatorImage = avatarUrl.isNotEmpty
        ? avatarUrl
        : (mediaType == 'image' && mediaUrl.isNotEmpty
            ? mediaUrl
            : "https://via.placeholder.com/150");

    final createdAtRaw = json['created_at']?.toString();
    final expiresAtRaw = json['expires_at']?.toString();
    final now = DateTime.now();
    final fallbackCreatedAt = now;
    final fallbackExpiresAt = now.add(const Duration(hours: 24));
    final createdAt = createdAtRaw != null
        ? (DateTime.tryParse(createdAtRaw) ?? fallbackCreatedAt)
        : fallbackCreatedAt;
    DateTime expiresAt = expiresAtRaw != null
        ? (DateTime.tryParse(expiresAtRaw) ?? fallbackExpiresAt)
        : fallbackExpiresAt;

    // Säkerställ alltid max 24h TTL (punkt 12)
    final maxExpires = createdAt.add(const Duration(hours: 24));
    if (expiresAt.isAfter(maxExpires)) expiresAt = maxExpires;

    return CreatorStatus(
      id: json['id'],
      creatorId: json['creator_id'],
      creatorName: json['creator_name'],
      creatorImage: creatorImage,
      isOnline: false,
      hasStory: true,
      mediaType: mediaType,
      createdAt: createdAt,
      expiresAt: expiresAt,
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
    DateTime? createdAt,
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
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      likeCount: likeCount ?? this.likeCount,
      likedByMe: likedByMe ?? this.likedByMe,
      videoUrl: videoUrl ?? this.videoUrl,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
