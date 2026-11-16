import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

/// Generates circular profile-photo marker icons for Google Maps.
/// Icons are cached per photo URL.
class MarkerIconHelper {
  MarkerIconHelper._();

  static const int _iconSize = 140;
  static final Map<String, BitmapDescriptor> _cache = {};

  /// Returns a circular [BitmapDescriptor] for [photoUrl].
  /// Falls back to a circle with [name]'s initial when no photo is available.
  static Future<BitmapDescriptor?> getIcon(String? photoUrl, {String? name}) async {
    if (photoUrl == null || photoUrl.isEmpty) return _initialIcon(name);
    final cached = _cache[photoUrl];
    if (cached != null) return cached;

    try {
      final response = await http
          .get(Uri.parse(photoUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return await _initialIcon(name);

      final bytes = await _circleImageBytes(
        response.bodyBytes,
        borderColor: Colors.white,
        borderWidth: 6.0,
      );
      if (bytes == null) return await _initialIcon(name);

      final descriptor = BitmapDescriptor.bytes(
        bytes,
        imagePixelRatio: 2.5,
      );
      _cache[photoUrl] = descriptor;
      return descriptor;
    } catch (_) {
      return _initialIcon(name);
    }
  }

  /// Generates a circular marker with the professional's initial.
  static Future<BitmapDescriptor?> _initialIcon(String? name) async {
    try {
      const size = 140.0;
      final initial = (name != null && name.trim().isNotEmpty)
          ? name.trim()[0].toUpperCase()
          : '?';

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      canvas.drawCircle(
        const Offset(size / 2, size / 2),
        size / 2,
        Paint()
          ..color = const Color(0xFF8A1C4E)
          ..isAntiAlias = true,
      );
      canvas.drawCircle(
        const Offset(size / 2, size / 2),
        size / 2 - 4,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..isAntiAlias = true,
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 56,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2),
      );

      final picture = recorder.endRecording();
      final rendered = await picture.toImage(_iconSize, _iconSize);
      final data = await rendered.toByteData(format: ui.ImageByteFormat.png);
      rendered.dispose();
      if (data == null) return null;
      return BitmapDescriptor.bytes(data.buffer.asUint8List(), imagePixelRatio: 2.5);
    } catch (_) {
      return null;
    }
  }

  /// Decodes image bytes, clips to a circle with a white ring, returns PNG bytes.
  static Future<Uint8List?> _circleImageBytes(
    Uint8List sourceBytes, {
    required Color borderColor,
    required double borderWidth,
  }) async {
    try {
      final codec = await ui.instantiateImageCodec(sourceBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final size = image.width.toDouble();

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // White border ring
      canvas.drawCircle(
        Offset(size / 2, size / 2),
        size / 2,
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );

      // Clip image to inner circle
      final clipPath = Path()
        ..addOval(Rect.fromCircle(
            center: Offset(size / 2, size / 2),
            radius: size / 2 - borderWidth));
      canvas.save();
      canvas.clipPath(clipPath);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(0, 0, size, size),
        Paint()..filterQuality = FilterQuality.high,
      );
      canvas.restore();

      final picture = recorder.endRecording();
      final rendered = await picture.toImage(_iconSize, _iconSize);
      final data = await rendered.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      rendered.dispose();
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }
}
