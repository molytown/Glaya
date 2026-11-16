class TrendingServiceModel {
  final String id;
  final String title;
  final String? imageUrl;
  final double priceFrom;
  final String? category;
  final String? serviceId;
  final int sortOrder;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TrendingServiceModel({
    required this.id,
    required this.title,
    this.imageUrl,
    required this.priceFrom,
    this.category,
    this.serviceId,
    required this.sortOrder,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory TrendingServiceModel.fromJson(Map<String, dynamic> json) {
    return TrendingServiceModel(
      id: json['id']?.toString() ?? '',
      title: (json['title'] ?? '').toString(),
      imageUrl: json['imageUrl']?.toString(),
      priceFrom: _parseNum(json['priceFrom'] ?? 0).toDouble(),
      category: json['category']?.toString(),
      serviceId: json['serviceId']?.toString(),
      sortOrder: _parseNum(json['sortOrder'] ?? 0).toInt(),
      isActive: json['isActive'] == true || json['isActive'] == null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  static num _parseNum(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.parse(value);
    return 0;
  }
}
