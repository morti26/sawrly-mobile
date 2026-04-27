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
  final int followersCount;
  final int followingCount;
  final bool isFollowing;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.bio,
    this.gender,
    this.avatarUrl,
    this.coverImageUrl,
    this.followersCount = 0,
    this.followingCount = 0,
    this.isFollowing = false,
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
      followersCount: json['followers_count'] ?? 0,
      followingCount: json['following_count'] ?? 0,
      isFollowing: json['is_following'] ?? false,
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
