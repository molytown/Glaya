import 'package:flutter/foundation.dart';

void loadGoogleMapsScript(String apiKey) {
  // No-op on mobile platforms
  if (kIsWeb) {
    print('Google Maps script loading not implemented on this platform');
  }
}
