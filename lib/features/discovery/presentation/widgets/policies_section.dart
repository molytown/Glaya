import 'package:flutter/material.dart';

import '../../../../shared/theme/colors.dart';
import '../../data/professional_model.dart';

class PoliciesSection extends StatelessWidget {
  final ProfessionalModel professional;

  const PoliciesSection({super.key, required this.professional});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Policies',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFEEEEEE)),
            ),
            child: Column(
              children: [
                _policyTile(
                  'Home Service',
                  professional.homeService
                      ? 'Available - Professional can come to your location'
                      : 'Not available - Visit salon for service',
                ),
                const Divider(height: 1),
                _policyTile(
                  'Location',
                  professional.displayArea ??
                      'Contact professional for location details',
                ),
                const Divider(height: 1),
                _policyTile(
                  'Cancellation',
                  'Contact professional to reschedule or cancel bookings',
                ),
                const Divider(height: 1),
                _policyTile(
                  'Payment',
                  'Deposit may be required for bookings, payable through the app',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _policyTile(String title, String content) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A1A1A),
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(
            content,
            style: const TextStyle(fontSize: 13, color: Color(0xFF555555)),
          ),
        ),
      ],
    );
  }
}
