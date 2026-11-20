import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/utils/haptic_feedback.dart';
import '../../../../shared/providers/location_provider.dart';
import '../../../discovery/presentation/discovery_provider.dart';
import '../../models/category.dart';

class HomeCategories extends ConsumerWidget {
  final List<HomeCategory> categories;
  final String? selectedLabel;
  final ValueChanged<String?> onSelected;

  const HomeCategories({
    super.key,
    required this.categories,
    required this.selectedLabel,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationState = ref.watch(locationProvider);
    final availableCategories = locationState.availableCategories;
    final categoriesAsync = ref.watch(homeCategoriesProvider);

    // Dynamic categories from the API, falling back to defaults on error/empty
    final apiCategories = categoriesAsync.valueOrNull;
    final sourceCategories = (apiCategories != null && apiCategories.isNotEmpty)
        ? [
            for (var i = 0; i < apiCategories.length; i++)
              HomeCategory.fromApi(apiCategories[i], i),
          ]
        : categories;

    // Filter categories based on zone availability
    List<HomeCategory> filteredCategories = sourceCategories;
    if (availableCategories != null && availableCategories.isNotEmpty) {
      filteredCategories = sourceCategories.where((category) {
        return availableCategories.contains(category.slug) ||
            availableCategories.contains(category.label.toLowerCase());
      }).toList();
    }

    // If no categories available in zone, show all with a warning
    final showWarning = availableCategories != null &&
        availableCategories.isNotEmpty &&
        filteredCategories.isEmpty;

    return Column(
      children: [
        if (showWarning)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Services not available in your area yet',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: filteredCategories.length,
            itemBuilder: (_, index) {
              final category = filteredCategories[index];
              final isSelected = selectedLabel == category.label;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.light();
                  if (category.slug == 'more') {
                    onSelected(isSelected ? null : category.label);
                  } else {
                    context.push(
                      '/category/${category.slug}?name=${Uri.encodeComponent(category.label)}',
                    );
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? GlayaColors.berry
                              : category.backgroundColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: GlayaColors.roseGold
                                        .withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [
                                  const BoxShadow(
                                    color: GlayaColors.softShadow,
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: Icon(
                          category.icon,
                          color: isSelected ? Colors.white : GlayaColors.berry,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        category.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected
                              ? GlayaColors.berry
                              : GlayaColors.textPrimary,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  .animate(delay: (index * 60).ms)
                  .fadeIn()
                  .scale(begin: const Offset(0.9, 0.9));
            },
          ),
        ),
      ],
    );
  }
}
