enum UserRole { creator, client }

class User {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? bio;
  final String? gender;
  final String? avatarUrl;
  final String? coverImageUrl;
  final String? country;
  final String? city;
  final String? subscriptionPlan;
  final String? subscriptionExpiresAt;
  final bool isSuperadmin;
  final String? superadminBadgeLabel;
  final String? superadminBadgeIconUrl;
  final int followersCount;
  final int followingCount;
  final bool isFollowing;
  final String? creatorLevelKey;
  final String? creatorLevelName;
  final String? creatorLevelIcon;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.bio,
    this.gender,
    this.avatarUrl,
    this.coverImageUrl,
    this.country,
    this.city,
    this.subscriptionPlan,
    this.subscriptionExpiresAt,
    this.isSuperadmin = false,
    this.superadminBadgeLabel,
    this.superadminBadgeIconUrl,
    this.followersCount = 0,
    this.followingCount = 0,
    this.isFollowing = false,
    this.creatorLevelKey,
    this.creatorLevelName,
    this.creatorLevelIcon,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'].toString().toLowerCase() == 'creator'
          ? UserRole.creator
          : UserRole.client,
      bio: json['bio'],
      gender: json['gender'],
      avatarUrl: json['avatar_url'],
      coverImageUrl: json['cover_image_url'],
      country: json['country'],
      city: json['city'],
      subscriptionPlan: json['subscription_plan'],
      subscriptionExpiresAt: json['subscription_expires_at']?.toString(),
      isSuperadmin: json['is_superadmin'] == true,
      superadminBadgeLabel: json['superadmin_badge_label'],
      superadminBadgeIconUrl: json['superadmin_badge_icon_url'],
      followersCount: json['followers_count'] ?? 0,
      followingCount: json['following_count'] ?? 0,
      isFollowing: json['is_following'] ?? false,
      creatorLevelKey: json['creator_level_key'],
      creatorLevelName: json['creator_level_name'],
      creatorLevelIcon: json['creator_level_icon'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role == UserRole.creator ? 'creator' : 'client',
      'bio': bio,
      'gender': gender,
      'avatar_url': avatarUrl,
      'cover_image_url': coverImageUrl,
      'country': country,
      'city': city,
      'subscription_plan': subscriptionPlan,
      'subscription_expires_at': subscriptionExpiresAt,
      'is_superadmin': isSuperadmin,
      'superadmin_badge_label': superadminBadgeLabel,
      'superadmin_badge_icon_url': superadminBadgeIconUrl,
      'creator_level_key': creatorLevelKey,
      'creator_level_name': creatorLevelName,
      'creator_level_icon': creatorLevelIcon,
    };
  }
}

// --- PHASE 4: CONTRACT AWARENESS ---
// Ideally these belong in project.dart and quote.dart,
// but we are adhering to strict file freeze.

enum ProjectStatus {
  draft,
  sent,
  accepted,
  booked,
  inProgress,
  delivered,
  approved,
  completed,
  cancelled,
}

class Project {
  final String id;
  final String quoteId;
  final ProjectStatus status;

  bool get isReadOnly =>
      status != ProjectStatus.draft && status != ProjectStatus.sent;

  Project({required this.id, required this.quoteId, required this.status});
}

class Quote {
  final String id;
  final double price;
  final double bookingFee;

  bool get hasNonRefundableBookingFee => bookingFee > 0;

  Quote({required this.id, required this.price, required this.bookingFee});
}
