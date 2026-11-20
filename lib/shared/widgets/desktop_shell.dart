import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/responsive_helper.dart';
import 'desktop_header.dart';
import 'notification_dropdown.dart';
import 'messages_dropdown.dart';
import 'auth_slide_out.dart';

class DesktopShell extends ConsumerStatefulWidget {
  final Widget child;
  final String path;

  const DesktopShell({super.key, required this.child, required this.path});

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell> {
  bool _showNotificationDropdown = false;
  bool _showMessagesDropdown = false;
  bool _showAuthSlideOut = false;

  @override
  Widget build(BuildContext context) {
    if (!ResponsiveHelper.isDesktop(context) || _isChromeless(widget.path)) {
      return widget.child;
    }
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Column(
            children: [
              DesktopHeader(
                showNotificationDropdown: _showNotificationDropdown,
                showMessagesDropdown: _showMessagesDropdown,
                onNotificationToggle: () {
                  setState(() => _showNotificationDropdown = !_showNotificationDropdown);
                  if (_showMessagesDropdown) {
                    setState(() => _showMessagesDropdown = false);
                  }
                },
                onMessagesToggle: () {
                  setState(() => _showMessagesDropdown = !_showMessagesDropdown);
                  if (_showNotificationDropdown) {
                    setState(() => _showNotificationDropdown = false);
                  }
                },
                onLoginTap: () {
                  setState(() => _showAuthSlideOut = true);
                },
              ),
              Expanded(child: widget.child),
            ],
          ),
          // Notification dropdown overlay
          if (_showNotificationDropdown)
            Positioned(
              top: 65,
              right: 50,
              child: NotificationDropdown(
                onClose: () {
                  setState(() => _showNotificationDropdown = false);
                },
              ),
            ),
          // Messages dropdown overlay
          if (_showMessagesDropdown)
            Positioned(
              top: 65,
              right: 100,
              child: MessagesDropdown(
                onClose: () {
                  setState(() => _showMessagesDropdown = false);
                },
              ),
            ),
          // Auth slide-out overlay
          if (_showAuthSlideOut)
            AuthSlideOut(
              isOpen: _showAuthSlideOut,
              onClose: () {
                setState(() => _showAuthSlideOut = false);
              },
            ),
        ],
      ),
    );
  }

  /// Routes that should not show the desktop header.
  static bool _isChromeless(String path) {
    return path == '/splash' ||
        path.startsWith('/admin') ||
        path == '/call' ||
        path.startsWith('/call/');
  }
}
