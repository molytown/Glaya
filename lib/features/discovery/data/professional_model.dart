import '../domain/professional.dart';
import '../../../shared/services/config_service.dart';

class ProfessionalModel extends Professional {
  const ProfessionalModel({
    required super.id,
    required super.userId,
    required super.name,
    required super.category,
    super.categories,
    required super.trustScore,
    super.photoUrl,
    super.bio,
    super.services,
    super.reviews,
    super.businessName,
    super.businessAddress,
    super.neighborhood,
    super.city,
    super.state,
    super.onlineStatus,
    super.avgRating,
    super.totalReviews,
    super.totalBookings,
    super.verificationStatus,
    super.homeService,
    super.portfolioUrls,
    super.availability,
    super.phone,
    super.createdAt,
    super.location,
    super.distance,
    super.currency,
    super.subscriptionType,
  });

  factory ProfessionalModel.fromJson(Map<String, dynamic> json) {
    final configService = ConfigService();

    // Handle category - can be String, Map, or null
    String categoryValue = '';
    final category = json['category'];
    if (category is String) {
      categoryValue = category;
    } else if (category is Map) {
      categoryValue =
          category['name']?.toString() ?? category['id']?.toString() ?? '';
    } else {
      categoryValue =
          (json['categoryId'] ?? json['category_id'] ?? '').toString();
    }

    final categoriesValue = _parseCategories(json['categories']);

    return ProfessionalModel(
      id: json['id']?.toString() ?? '',
      userId: (json['user']?['id'] ?? json['userId'] ?? json['user_id'] ?? '')
          .toString(),
      name: (json['user']?['name'] ?? 'Unknown').toString(),
      category: categoryValue,
      categories: categoriesValue.isNotEmpty
          ? categoriesValue
          : (categoryValue.isNotEmpty ? [categoryValue] : const <String>[]),
      trustScore:
          _parseNum(json['trustScore'] ?? json['trust_score'] ?? 0).toInt(),
      photoUrl: configService.replaceLocalhost(
        (json['user']?['photoUrl'] as String?) ??
            (json['user']?['photo_url'] as String?) ??
            (json['photoUrl'] as String?) ??
            (json['photo_url'] as String?) ??
            '',
      ),
      bio: json['bio']?.toString(),
      services: (json['services'] as List<dynamic>?)
          ?.map((s) => ServiceItem.fromJson(s as Map<String, dynamic>))
          .toList(),
      reviews: (json['reviews'] as List<dynamic>?)
          ?.map((r) => ReviewItem.fromJson(r as Map<String, dynamic>))
          .toList(),
      businessName:
          json['businessName']?.toString() ?? json['business_name']?.toString(),
      businessAddress: json['businessAddress']?.toString() ??
          json['business_address']?.toString(),
      neighborhood: json['neighborhood']?.toString() ??
          json['area']?.toString() ??
          json['neighbourhood']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      onlineStatus: (json['dynamicOnlineStatus'] ??
              json['dynamic_online_status'] ??
              json['onlineStatus'] ??
              json['online_status'])
          ?.toString(),
      avgRating: _parseNum(json['avgRating'] ?? json['avg_rating']).toDouble(),
      totalReviews: _parseNum(
        json['totalReviews'] ?? json['total_reviews'] ?? 0,
      ).toInt(),
      totalBookings: _parseNum(
        json['totalBookings'] ?? json['total_bookings'] ?? 0,
      ).toInt(),
      verificationStatus:
          (json['verificationStatus'] ?? json['verification_status'])
                  ?.toString() ??
              'pending',
      homeService: (json['homeService'] as bool?) ??
          (json['home_service'] as bool?) ??
          false,
      portfolioUrls: json['portfolioGalleries'] as List<dynamic>? ?? [],
      availability: json['availability'] as List<dynamic>?,
      phone: (json['user']?['phone'] ?? json['phone'])?.toString(),
      createdAt: DateTime.tryParse(
        (json['createdAt'] ?? json['created_at'])?.toString() ?? '',
      ),
      location: json['location'] as Map<String, dynamic>?,
      distance: _parseNum(json['distance']).toDouble(),
      currency: json['currency']?.toString(),
      subscriptionType:
          (json['subscriptionType'] ?? json['subscription_type'])?.toString() ??
              'flex',
    );
  }

  static List<String> _parseCategories(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((e) {
          if (e is String) return e;
          if (e is Map) {
            return (e['name'] ?? e['title'] ?? '').toString();
          }
          return '';
        })
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static num _parseNum(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.parse(value);
    return 0;
  }
}

class ServiceItem {
  final String id;
  final String name;
  final double price;
  final int durationMins;
  final double? depositAmount;
  final String? imageUrl;

  const ServiceItem({
    required this.id,
    required this.name,
    required this.price,
    required this.durationMins,
    this.depositAmount,
    this.imageUrl,
  });

  factory ServiceItem.fromJson(Map<String, dynamic> json) {
    return ServiceItem(
      id: json['id']?.toString() ?? '',
      name: (json['name'] ?? '').toString(),
      price: ProfessionalModel._parseNum(json['price'] ?? 0).toDouble(),
      durationMins: ProfessionalModel._parseNum(
        json['durationMins'] ?? json['duration_mins'] ?? 30,
      ).toInt(),
      depositAmount:
          json['depositAmount'] != null || json['deposit_amount'] != null
              ? ProfessionalModel._parseNum(
                  json['depositAmount'] ?? json['deposit_amount'],
                ).toDouble()
              : null,
      imageUrl: (json['imageUrl'] ?? json['image_url'])?.toString(),
    );
  }
}

class ReviewItem {
  final String? id;
  final String? reviewerId;
  final String reviewerName;
  final int rating;
  final String? comment;
  final String? createdAt;

  const ReviewItem({
    this.id,
    this.reviewerId,
    required this.reviewerName,
    required this.rating,
    this.comment,
    this.createdAt,
  });

  factory ReviewItem.fromJson(Map<String, dynamic> json) {
    return ReviewItem(
      id: json['id']?.toString(),
      reviewerId:
          (json['reviewerId'] ?? json['reviewer_id'] ?? json['reviewer']?['id'])
              ?.toString(),
      reviewerName: (json['reviewer']?['name'] ?? 'Anonymous').toString(),
      rating: ProfessionalModel._parseNum(json['rating']).toInt(),
      comment: json['comment']?.toString(),
      createdAt: (json['createdAt'] ?? json['created_at'])?.toString(),
    );
  }
}

class AvailabilitySlot {
  final String time;
  final bool isBooked;

  const AvailabilitySlot({required this.time, required this.isBooked});

  factory AvailabilitySlot.fromJson(Map<String, dynamic> json) {
    return AvailabilitySlot(
      time: (json['time'] ?? '').toString(),
      isBooked: json['isBooked'] == true || json['is_booked'] == true,
    );
  }
}
