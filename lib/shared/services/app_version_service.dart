import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/colors.dart';

/// Checks Firebase Remote Config for `latest_version` / `min_version` and
/// prompts the user to update when the installed build is outdated.
///
/// Remote Config keys:
///   latest_version   - newest published version (e.g. "1.2.0")
///   min_version      - oldest allowed version; below this = forced update
///   update_url_ios   - App Store URL
///   update_url_android - Play Store URL
class AppVersionService {
  static const _kLatestVersion = 'latest_version';
  static const _kMinVersion = 'min_version';
  static const _kUpdateUrlIos = 'update_url_ios';
  static const _kUpdateUrlAndroid = 'update_url_android';
  static const _kDismissedKey = 'version_check_dismissed';

  /// Entry point — safe to call on every cold start. No-ops silently on any
  /// failure (offline, Firebase not ready, etc.).
  static Future<void> checkAndPrompt(BuildContext context) async {
    try {
      if (kIsWeb || Firebase.apps.isEmpty) return;

      final info = await PackageInfo.fromPlatform();
      final installed = info.version;

      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      await rc.setDefaults({
        _kLatestVersion: installed,
        _kMinVersion: installed,
        _kUpdateUrlIos: '',
        _kUpdateUrlAndroid:
            'https://play.google.com/store/apps/details?id=com.glaya.app',
      });
      await rc.fetchAndActivate();

      final latest = rc.getString(_kLatestVersion);
      final min = rc.getString(_kMinVersion);
      final storeUrl = Platform.isIOS
          ? rc.getString(_kUpdateUrlIos)
          : rc.getString(_kUpdateUrlAndroid);

      if (!_isNewer(latest, installed)) return;

      final forced = _isNewer(min, installed);
      if (!forced) {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getString(_kDismissedKey) == latest) return;
      }
      if (!context.mounted) return;

      await _showUpdateDialog(
        context,
        latestVersion: latest,
        forced: forced,
        storeUrl: storeUrl,
      );
    } catch (_) {
      // Version check must never break the app
    }
  }

  static bool _isNewer(String candidate, String installed) {
    int compare(String a, String b) {
      final pa = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final pb = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      for (var i = 0; i < 3; i++) {
        final va = i < pa.length ? pa[i] : 0;
        final vb = i < pb.length ? pb[i] : 0;
        if (va != vb) return va.compareTo(vb);
      }
      return 0;
    }

    final c = candidate.trim();
    if (c.isEmpty) return false;
    return compare(c, installed.trim()) > 0;
  }

  static Future<void> _showUpdateDialog(
    BuildContext context, {
    required String latestVersion,
    required bool forced,
    required String storeUrl,
  }) async {
    final dismissed = await showDialog<bool>(
      context: context,
      barrierDismissible: !forced,
      builder: (ctx) => PopScope(
        canPop: !forced,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.system_update_alt,
                  color: GlayaColors.vibrantPink, size: 26),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Update available',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          content: Text(
            forced
                ? 'A new version (v$latestVersion) is required to continue using Glaya. Please update to keep booking and earning.'
                : 'Glaya v$latestVersion is available with improvements and fixes. Update now for the best experience.',
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            if (!forced)
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Later'),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: GlayaColors.vibrantPink,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.of(ctx).pop(true);
                if (storeUrl.isNotEmpty) {
                  final uri = Uri.parse(storeUrl);
                  await launchUrl(uri,
                      mode: LaunchMode.externalApplication);
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );

    if (dismissed == false) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kDismissedKey, latestVersion);
    }
  }
}
