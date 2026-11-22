import '../../../../shared/services/api_service.dart';

/// Thin API wrapper for the standalone Ambassador program
/// (`/api/v1/ambassadors/*`). Completely separate from Refer & Earn.
class AmbassadorRepository {
  Future<Map<String, dynamic>?> getProfile() async {
    final resp = await ApiService.dio.get('/ambassadors/me');
    final data = resp.data['data'];
    if (data is Map<String, dynamic> && data['isAmbassador'] == true) {
      return data;
    }
    return null;
  }

  Future<Map<String, dynamic>> getReferrals(
      {int page = 1, int limit = 15}) async {
    final resp = await ApiService.dio.get(
      '/ambassadors/me/referrals',
      queryParameters: {'page': page, 'limit': limit},
    );
    return _page(resp.data);
  }

  Future<Map<String, dynamic>> getCommissions(
      {int page = 1, int limit = 15}) async {
    final resp = await ApiService.dio.get(
      '/ambassadors/me/commissions',
      queryParameters: {'page': page, 'limit': limit},
    );
    return _page(resp.data);
  }

  Future<Map<String, dynamic>> getPayouts(
      {int page = 1, int limit = 15}) async {
    final resp = await ApiService.dio.get(
      '/ambassadors/me/payouts',
      queryParameters: {'page': page, 'limit': limit},
    );
    return _page(resp.data);
  }

  Future<Map<String, dynamic>> getLedger({int page = 1, int limit = 15}) async {
    final resp = await ApiService.dio.get(
      '/ambassadors/me/ledger',
      queryParameters: {'page': page, 'limit': limit},
    );
    return _page(resp.data);
  }

  Future<Map<String, dynamic>> requestPayout({
    required double amount,
    required String method,
    required Map<String, dynamic> accountDetails,
  }) async {
    final resp = await ApiService.dio.post(
      '/ambassadors/me/payouts',
      data: {
        'amount': amount,
        'method': method,
        'accountDetails': accountDetails
      },
    );
    return resp.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> transferToWallet({required double amount}) async {
    final resp = await ApiService.dio.post(
      '/ambassadors/me/wallet-transfer',
      data: {'amount': amount},
    );
    return (resp.data['data'] as Map?)?.cast<String, dynamic>() ?? {};
  }

  Map<String, dynamic> _page(dynamic body) {
    final data = (body is Map ? body['data'] : null) ?? [];
    final meta = (body is Map ? body['meta'] : null) ?? {};
    return {
      'items': data is List ? data : [],
      'total': (meta is Map ? meta['total'] : 0) ?? 0,
    };
  }
}
