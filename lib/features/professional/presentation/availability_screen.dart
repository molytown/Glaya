import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/text_styles.dart';

class AvailabilityScreen extends ConsumerStatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  ConsumerState<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends ConsumerState<AvailabilityScreen> {
  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final List<List<bool>> _slots = List.generate(7, (_) => List.generate(24, (_) => false));
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    try {
      final response = await ApiService.dio.get('/services/availability/me');
      final rules = response.data['data'] as List<dynamic>;
      for (final rule in rules) {
        final r = rule as Map<String, dynamic>;
        final day = (r['dayOfWeek'] as int?) ?? 0;
        final startTime = r['startTime'] as String? ?? '00:00';
        final endTime = r['endTime'] as String? ?? '00:00';
        final isBlocked = r['isBlocked'] as bool? ?? false;
        if (!isBlocked && day >= 0 && day < 7) {
          final startHour = int.tryParse(startTime.split(':')[0]) ?? 0;
          final endHour = int.tryParse(endTime.split(':')[0]) ?? 0;
          for (int h = startHour; h < endHour && h < 24; h++) {
            setState(() => _slots[day][h] = true);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load availability: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAvailability() async {
    try {
      for (int day = 0; day < 7; day++) {
        final start = _slots[day].indexOf(true);
        if (start != -1) {
          int end = start;
          while (end < 24 && _slots[day][end]) end++;
          final startTime = '${start.toString().padLeft(2, '0')}:00';
          final endTime = '${end.toString().padLeft(2, '0')}:00';
          await ApiService.dio.post('/services/availability', data: {
            'dayOfWeek': day,
            'startTime': startTime,
            'endTime': endTime,
            'isBlocked': false,
          });
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Availability saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Availability'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveAvailability,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  for (int day = 0; day < 7; day++) ...[
                    Text(_days[day], style: GlayaTextStyles.titleMedium()),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: List.generate(24, (hour) {
                        return FilterChip(
                          label: Text('${hour.toString().padLeft(2, '0')}:00'),
                          selected: _slots[day][hour],
                          selectedColor: GlayaColors.berry,
                          labelStyle: TextStyle(
                            color: _slots[day][hour] ? Colors.white : GlayaColors.textPrimary,
                            fontSize: 10,
                          ),
                          onSelected: (selected) {
                            setState(() => _slots[day][hour] = selected);
                          },
                        );
                      }),
                    ),
                    const Divider(),
                  ],
                ],
              ),
            ),
    );
  }
}
