class User {
  final String id;
  final String phone;
  final String? name;
  final String? photoUrl;
  final String role;
  final int reliabilityScore;
  final String? preferredCurrency;
  final String? professionalId;

  const User({
    required this.id,
    required this.phone,
    this.name,
    this.photoUrl,
    required this.role,
    required this.reliabilityScore,
    this.preferredCurrency,
    this.professionalId,
  });
}
