import 'package:flutter/material.dart';
import '../../../../shared/theme/colors.dart';

class AvailabilityCard extends StatelessWidget {
  final List<dynamic>? availability;

  const AvailabilityCard({super.key, this.availability});

  static const _days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  Widget build(BuildContext context) {
    final slotsByDay = <int, List<Map<String, dynamic>>>{};
    for (final a in availability ?? const []) {
      final day = a['dayOfWeek'] as int? ?? a['day_of_week'] as int? ?? 0;
      slotsByDay.putIfAbsent(day, () => []).add(a as Map<String, dynamic>);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFEEEEEE))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Weekly Availability',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1A))),
              const SizedBox(height: 12),
              if ((availability ?? []).isEmpty)
                const Text('No schedule available',
                    style: TextStyle(fontSize: 14, color: Color(0xFF000000)))
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 6,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: 7,
                  itemBuilder: (_, i) {
                    final slots = slotsByDay[i] ?? const [];
                    final hasOpen = slots.any((s) =>
                        !(s['isBlocked'] as bool? ??
                            s['is_blocked'] as bool? ??
                            false));
                    final isOff = slots.isEmpty;
                    return Column(
                      children: [
                        Text(_days[i],
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF000000))),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: isOff
                                  ? const Color(0xFFF5F5F5)
                                  : hasOpen
                                      ? const Color(0xFFE8F5E9)
                                      : const Color(0xFFF8BBD0),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                isOff ? '—' : (hasOpen ? 'Open' : 'Full'),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isOff
                                      ? const Color(0xFFCCCCCC)
                                      : hasOpen
                                          ? const Color(0xFF2E7D32)
                                          : const Color(0xFFC62828),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
