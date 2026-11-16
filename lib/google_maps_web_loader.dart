import 'dart:html' as html;
import 'package:flutter/foundation.dart';

void loadGoogleMapsScript(String apiKey) {
  if (kIsWeb && apiKey.isNotEmpty) {
    html.window.localStorage['googleMapsApiKey'] = apiKey;
    print('Google Maps API key saved to localStorage');
  }
}
