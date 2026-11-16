import 'package:flutter/material.dart';

class HomeCategory {
  final String label;
  final String slug;
  final IconData icon;
  final Color backgroundColor;

  const HomeCategory({
    required this.label,
    required this.slug,
    required this.icon,
    required this.backgroundColor,
  });

  static const defaults = [
    HomeCategory(label: 'Hair', slug: 'hair', icon: Icons.content_cut, backgroundColor: Color(0xFFFFE0EC)),
    HomeCategory(label: 'Makeup', slug: 'makeup', icon: Icons.face_retouching_natural, backgroundColor: Color(0xFFEDE7F6)),
    HomeCategory(label: 'Nails', slug: 'nails', icon: Icons.brush, backgroundColor: Color(0xFFFFF8E1)),
    HomeCategory(label: 'Skincare', slug: 'skincare', icon: Icons.spa, backgroundColor: Color(0xFFE0F2F1)),
    HomeCategory(label: 'Massage', slug: 'massage', icon: Icons.self_improvement, backgroundColor: Color(0xFFE8F5E9)),
    HomeCategory(label: 'More', slug: 'more', icon: Icons.more_horiz, backgroundColor: Color(0xFFF5F5F5)),
  ];

  static const _palette = [
    Color(0xFFFFE0EC), Color(0xFFEDE7F6), Color(0xFFFFF8E1),
    Color(0xFFE0F2F1), Color(0xFFE8F5E9), Color(0xFFF8BBD0),
    Color(0xFFE3F2FD), Color(0xFFF3E5F5), Color(0xFFFFF3E0),
    Color(0xFFE8EAF6), Color(0xFFE0F7FA), Color(0xFFFBE9E7),
    Color(0xFFF1F8E9),
  ];

  static IconData iconFor(String? key) => switch (key) {
        'scissors' => Icons.content_cut,
        'droplet' => Icons.water_drop_outlined,
        'user' => Icons.person_outline,
        'sparkles' => Icons.auto_awesome_outlined,
        'palette' => Icons.palette_outlined,
        'eye' => Icons.visibility_outlined,
        'brush' => Icons.brush_outlined,
        'heart' => Icons.favorite_border,
        'sparkle' => Icons.star_outline,
        'hands' => Icons.spa_outlined,
        'flame' => Icons.local_fire_department_outlined,
        'eye-off' => Icons.visibility_off_outlined,
        'activity' => Icons.fitness_center_outlined,
        _ => Icons.category_outlined,
      };

  factory HomeCategory.fromApi(Map<String, dynamic> data, int index) {
    final label = (data['name'] ?? 'Category').toString();
    final slug = (data['slug'] ?? label.toLowerCase().replaceAll(' ', '_')).toString();
    return HomeCategory(
      label: label,
      slug: slug,
      icon: iconFor(data['icon']?.toString()),
      backgroundColor: _palette[index % _palette.length],
    );
  }
}
