import 'package:flutter/material.dart';
import '../theme/colors.dart';

class CustomDateTimePicker extends StatefulWidget {
  final Function(DateTime date, String time) onConfirm;
  final List<String>? availableTimeSlots;
  final DateTime? minDate;
  final DateTime? maxDate;

  const CustomDateTimePicker({
    super.key,
    required this.onConfirm,
    this.availableTimeSlots,
    this.minDate,
    this.maxDate,
  });

  @override
  State<CustomDateTimePicker> createState() => _CustomDateTimePickerState();
}

class _CustomDateTimePickerState extends State<CustomDateTimePicker> {
  int _selectedMonthIndex = 0;
  int _selectedDayIndex = 0;
  String? _selectedTime;

  @override
  void initState() {
    super.initState();
    _initializeDefaults();
  }

  void _initializeDefaults() {
    final now = DateTime.now();
    _selectedMonthIndex = now.month - 1;
    _selectedDayIndex = now.day - 1;
  }

  List<DateTime> _getDaysInMonth(int year, int month) {
    final lastDay = DateTime(year, month + 1, 0);
    final days = <DateTime>[];
    
    for (int i = 0; i < lastDay.day; i++) {
      days.add(DateTime(year, month, i + 1));
    }
    
    return days;
  }

  List<String> _getMonths() {
    return [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
  }

  List<String> _getTimeSlots() {
    return widget.availableTimeSlots ?? [
      '09:00', '10:00', '11:00', '12:00', '13:00', '14:00',
      '15:00', '16:00', '17:00', '18:00'
    ];
  }

  void _handleConfirm() {
    final currentYear = DateTime.now().year;
    final selectedDate = DateTime(currentYear, _selectedMonthIndex + 1, _selectedDayIndex + 1);
    
    widget.onConfirm(selectedDate, _selectedTime ?? _getTimeSlots().first);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    final daysInMonth = _getDaysInMonth(currentYear, _selectedMonthIndex + 1);
    final months = _getMonths();
    final timeSlots = _getTimeSlots();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Date & Time',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: GlayaColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Month selector
            const Text(
              'Month',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF000000),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: months.length,
                itemBuilder: (context, index) {
                  final isSelected = index == _selectedMonthIndex;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedMonthIndex = index),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? GlayaColors.berry : GlayaColors.blushPink,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        months[index].substring(0, 3),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : GlayaColors.textPrimary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Day selector
            const Text(
              'Day',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF000000),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: daysInMonth.length,
                itemBuilder: (context, index) {
                  final isSelected = index == _selectedDayIndex;
                  final day = daysInMonth[index];
                  return GestureDetector(
                    onTap: () => setState(() => _selectedDayIndex = index),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? GlayaColors.berry : GlayaColors.blushPink,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        day.day.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : GlayaColors.textPrimary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Time selector
            const Text(
              'Time',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF000000),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: timeSlots.map((time) {
                final isSelected = time == _selectedTime;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTime = time),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? GlayaColors.berry : GlayaColors.blushPink,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      time,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : GlayaColors.textPrimary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Confirm button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedTime != null ? _handleConfirm : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlayaColors.berry,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Color(0xFF000000),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Confirm Selection',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
