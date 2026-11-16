import 'package:flutter_test/flutter_test.dart';
import 'package:glaya/features/auth/domain/entities/user.dart';
import 'package:glaya/features/auth/data/repositories/auth_repository_impl.dart';

void main() {
  group('AuthRepositoryImpl', () {
    late AuthRepositoryImpl repository;

    setUp(() {
      repository = AuthRepositoryImpl();
    });

    test('initial authentication is false', () async {
      expect(await repository.isAuthenticated, false);
    });

    test('User entity has correct fields', () {
      const user = User(
        id: '1',
        phone: '+123',
        role: 'customer',
        reliabilityScore: 50,
      );
      expect(user.phone, '+123');
      expect(user.role, 'customer');
      expect(user.reliabilityScore, 50);
    });
  });
}
