import 'package:shared_preferences/shared_preferences.dart';

/// Ambassador referral attribution — mirrors
/// frontend/src/utils/ambassadorAttribution.js.
///
/// Codes arrive via `?ambassador=CODE` links (web URL opened through App
/// Links / a glaya:// deep link) or an in-app route query param, and are held
/// in SharedPreferences until signup completes — same persistence semantics
/// as the React app's localStorage key.
const _key = 'glaya_ambassador_code';
final _codePattern = RegExp(r'^[A-Z0-9]{4,20}$');

/// Validates and stores [raw] as the pending ambassador code.
/// Returns the normalized code, or null when invalid/empty.
Future<String?> captureAmbassadorCode(String? raw) async {
  final code = (raw ?? '').trim().toUpperCase();
  if (code.isEmpty || !_codePattern.hasMatch(code)) return null;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_key, code);
  return code;
}

/// Captures the `ambassador` query param from [uri]; falls back to [rawCode]
/// when the URI carries no param. Returns the stored code or null.
Future<String?> captureFromUri(Uri? uri, {String? rawCode}) async {
  final fromUri = uri?.queryParameters['ambassador'];
  return captureAmbassadorCode(fromUri ?? rawCode);
}

/// The pending ambassador code, or null when none was captured.
Future<String?> getAmbassadorCode() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_key);
}

/// Clears the pending code — call after a successful signup/verify.
Future<void> clearAmbassadorCode() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_key);
}
