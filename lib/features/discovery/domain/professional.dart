class Professional {
  final String id;
  final String userId;
  final String name;
  final String category;
  final List<String> categories;
  final int trustScore;
  final String? photoUrl;
  final String? bio;
  final List<dynamic>? services;
  final List<dynamic>? reviews;
  final String? businessName;
  final String? businessAddress;
  final String? neighborhood;
  final String? city;
  final String? state;
  final String? onlineStatus;
  final double? avgRating;
  final int totalReviews;
  final int totalBookings;
  final String verificationStatus;
  final bool homeService;
  final List<dynamic>? portfolioUrls;
  final List<dynamic>? availability;
  final String? phone;
  final DateTime? createdAt;
  final Map<String, dynamic>? location;
  final double? distance;
  final String? currency;
  final String subscriptionType;

  const Professional({
    required this.id,
    required this.userId,
    required this.name,
    required this.category,
    this.categories = const [],
    required this.trustScore,
    this.photoUrl,
    this.bio,
    this.services,
    this.reviews,
    this.businessName,
    this.businessAddress,
    this.neighborhood,
    this.city,
    this.state,
    this.onlineStatus,
    this.avgRating,
    this.totalReviews = 0,
    this.totalBookings = 0,
    this.verificationStatus = 'pending',
    this.homeService = false,
    this.portfolioUrls,
    this.availability,
    this.phone,
    this.createdAt,
    this.location,
    this.distance,
    this.currency,
    this.subscriptionType = 'flex',
  });

  /// Mirrors the web `calculateAvailability` util — derives open/closed from
  /// the professional's opening-hours rules using the device's local time.
  /// Returns null when no rules are set so callers can fall back to
  /// [onlineStatus].
  String? get calculatedAvailabilityStatus {
    final rules = availability;
    if (rules == null || rules.isEmpty) return null;

    final now = DateTime.now();
    // JS getDay(): 0=Sunday..6=Saturday; Dart weekday: Mon=1..Sun=7
    final jsDay = now.weekday % 7;
    final nowMinutes = now.hour * 60 + now.minute;

    for (final r in rules) {
      if (r is! Map) continue;
      final rule = Map<String, dynamic>.from(r);
      if ((rule['dayOfWeek'] as num?)?.toInt() != jsDay) continue;
      if (rule['isBlocked'] == true) continue;
      final start = _minutesOfDay(rule['startTime']);
      final end = _minutesOfDay(rule['endTime']);
      if (start == null || end == null) continue;
      return nowMinutes >= start && nowMinutes < end ? 'online' : 'offline';
    }
    return 'offline';
  }

  /// Status used by cards — same priority as React:
  /// calculated opening-hours status first, then backend onlineStatus.
  String get cardStatus =>
      calculatedAvailabilityStatus ?? onlineStatus ?? 'offline';

  static int? _minutesOfDay(dynamic v) {
    final parts = v?.toString().split(':');
    if (parts == null || parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  /// Best available human-readable area: neighborhood → "city, state" → business address
  String? get displayArea {
    if (neighborhood?.isNotEmpty == true) return neighborhood;
    final cityState = [city, state]
        .where((s) => s != null && s.isNotEmpty)
        .join(', ');
    if (cityState.isNotEmpty) return cityState;
    if (businessAddress?.isNotEmpty == true) return businessAddress;
    return null;
  }
}
