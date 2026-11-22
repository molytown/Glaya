import '../../domain/entities/user.dart';

class UserModel extends User {
  const UserModel({
    required super.id,
    required super.phone,
    super.name,
    super.photoUrl,
    required super.role,
    required super.reliabilityScore,
    super.preferredCurrency,
    super.professionalId,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Backend returns TypeORM entity (camelCase); accept snake_case too
    return UserModel(
      id: (json['id'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      name: (json['name'] ?? json['full_name'])?.toString(),
      photoUrl: (json['photoUrl'] ?? json['photo_url'])?.toString(),
      role: (json['role'] ?? 'user').toString(),
      reliabilityScore:
          ((json['reliabilityScore'] ?? json['reliability_score']) as num?)
                  ?.toInt() ??
              0,
      preferredCurrency:
          (json['preferredCurrency'] ?? json['preferred_currency'])
                  ?.toString() ??
              'XAF',
      professionalId:
          (json['professionalId'] ?? json['professional_id'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'name': name,
      'photoUrl': photoUrl,
      'role': role,
      'reliabilityScore': reliabilityScore,
      'preferredCurrency': preferredCurrency,
      'professionalId': professionalId,
    };
  }
}
