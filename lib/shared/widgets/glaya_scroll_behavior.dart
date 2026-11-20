import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Enables mouse press-and-drag ("hold and pull") scrolling on desktop/web.
/// Flutter's default [MaterialScrollBehavior] only accepts touch/stylus drag
/// devices, so horizontal carousels can't be dragged with a mouse. Touch
/// behavior on mobile is unchanged.
class GlayaScrollBehavior extends MaterialScrollBehavior {
  const GlayaScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.unknown,
      };
}
