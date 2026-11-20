import 'package:flutter/material.dart';

/// Subscription verification badge — mirrors the React VerificationBadge component.
/// flex (default) → blue shield "Pro"; elite → gold crown "Elite".
class VerificationBadge extends StatelessWidget {
  final String? subscriptionType;
  final VerificationBadgeSize size;

  const VerificationBadge({
    super.key,
    this.subscriptionType,
    this.size = VerificationBadgeSize.small,
  });

  @override
  Widget build(BuildContext context) {
    final type = (subscriptionType ?? 'flex').toLowerCase();
    final isElite = type == 'elite';

    final color = isElite ? const Color(0xFFFFD700) : const Color(0xFF3B82F6);
    final icon = isElite ? Icons.workspace_premium : Icons.verified_user;
    final label = isElite ? 'Elite' : 'Pro';

    final isSmall = size == VerificationBadgeSize.small;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 6 : 10,
        vertical: isSmall ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isSmall ? 11 : 13, color: color),
          SizedBox(width: isSmall ? 3 : 4),
          Text(
            label,
            style: TextStyle(
              fontSize: isSmall ? 10 : 12,
              fontWeight: FontWeight.w600,
              color: color,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

enum VerificationBadgeSize { small, medium }
