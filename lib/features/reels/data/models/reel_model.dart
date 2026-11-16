int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

class Reel {
  final String id;
  final String videoUrl;
  final String? title;
  final String? description;
  final int likes;
  final int views;
  final int shares;
  final DateTime createdAt;
  final ReelUser? user;
  final ReelProfessional? taggedProfessional;
  final String? serviceId;
  final String? serviceName;
  final String userType;
  final String mediaType;

  bool get isPhoto => mediaType == 'photo';
  bool get isUserReel => userType == 'user';

  Reel({
    required this.id,
    required this.videoUrl,
    this.title,
    this.description,
    required this.likes,
    required this.views,
    required this.shares,
    required this.createdAt,
    this.user,
    this.taggedProfessional,
    this.serviceId,
    this.serviceName,
    this.userType = 'user',
    this.mediaType = 'video',
  });

  factory Reel.fromJson(Map<String, dynamic> json) {
    return Reel(
      id: json['id']?.toString() ?? '',
      videoUrl: json['videoUrl']?.toString() ?? '',
      title: json['title']?.toString(),
      description: json['description']?.toString(),
      likes: _toInt(json['likes']) ?? 0,
      views: _toInt(json['views']) ?? 0,
      shares: _toInt(json['shares']) ?? 0,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      user: json['user'] != null ? ReelUser.fromJson(json['user'] as Map<String, dynamic>) : null,
      taggedProfessional: json['taggedProfessional'] != null
          ? ReelProfessional.fromJson(json['taggedProfessional'] as Map<String, dynamic>)
          : null,
      serviceId: json['serviceId']?.toString(),
      serviceName: json['service'] is Map ? (json['service']['name']?.toString()) : null,
      userType: json['userType']?.toString() ?? 'user',
      mediaType: json['mediaType']?.toString() ?? 'video',
    );
  }
}

class ReelUser {
  final String id;
  final String? name;
  final String? photoUrl;

  ReelUser({
    required this.id,
    this.name,
    this.photoUrl,
  });

  factory ReelUser.fromJson(Map<String, dynamic> json) {
    return ReelUser(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString(),
      photoUrl: json['photoUrl']?.toString(),
    );
  }
}

class ReelProfessional {
  final String id;
  final String? categoryId;
  final ReelUser? user;
  final int? totalBookings;
  final ReelBoost? boost;
  final String subscriptionType;

  ReelProfessional({
    required this.id,
    this.categoryId,
    this.user,
    this.totalBookings,
    this.boost,
    this.subscriptionType = 'flex',
  });

  factory ReelProfessional.fromJson(Map<String, dynamic> json) {
    return ReelProfessional(
      id: json['id']?.toString() ?? '',
      categoryId: json['categoryId']?.toString(),
      user: json['user'] != null ? ReelUser.fromJson(json['user'] as Map<String, dynamic>) : null,
      totalBookings: _toInt(json['totalBookings']),
      boost: json['boost'] != null ? ReelBoost.fromJson(json['boost'] as Map<String, dynamic>) : null,
      subscriptionType:
          (json['subscriptionType'] ?? json['subscription_type'])?.toString() ??
          'flex',
    );
  }
}

class ReelEngagement {
  int likes;
  int shares;
  int views;
  bool liked;

  ReelEngagement({
    required this.likes,
    required this.shares,
    required this.views,
    this.liked = false,
  });

  ReelEngagement copy() => ReelEngagement(
        likes: likes,
        shares: shares,
        views: views,
        liked: liked,
      );

  factory ReelEngagement.fromReel(Reel reel) => ReelEngagement(
        likes: reel.likes,
        shares: reel.shares,
        views: reel.views,
      );
}

class ReelBoost {
  final bool isActive;
  final int? rank;

  ReelBoost({
    required this.isActive,
    this.rank,
  });

  factory ReelBoost.fromJson(Map<String, dynamic> json) {
    return ReelBoost(
      isActive: json['isActive'] as bool? ?? false,
      rank: _toInt(json['rank']),
    );
  }
}
