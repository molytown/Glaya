class PromotionModel {
  final String id;
  final String title;
  final String? description;
  final double discountPercent;
  final String code;
  final DateTime validFrom;
  final DateTime validTo;
  final bool isActive;
  final String targetRole;
  final int usageCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  PromotionModel({
    required this.id,
    required this.title,
    this.description,
    required this.discountPercent,
    required this.code,
    required this.validFrom,
    required this.validTo,
    required this.isActive,
    required this.targetRole,
    required this.usageCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PromotionModel.fromJson(Map<String, dynamic> json) {
    return PromotionModel(
      id: json['id']?.toString() ?? '',
      title: (json['title'] ?? '').toString(),
      description: json['description']?.toString(),
      discountPercent: (json['discountPercent'] as num? ?? 0).toDouble(),
      code: (json['code'] ?? '').toString(),
      validFrom: DateTime.tryParse(json['validFrom']?.toString() ?? '') ??
          DateTime.now(),
      validTo:
          DateTime.tryParse(json['validTo']?.toString() ?? '') ?? DateTime.now(),
      isActive: json['isActive'] == true,
      targetRole: (json['targetRole'] ?? 'all').toString(),
      usageCount: (json['usageCount'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'discountPercent': discountPercent,
      'code': code,
      'validFrom': validFrom.toIso8601String(),
      'validTo': validTo.toIso8601String(),
      'isActive': isActive,
      'targetRole': targetRole,
      'usageCount': usageCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
