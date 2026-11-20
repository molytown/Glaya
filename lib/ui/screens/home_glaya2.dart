import 'package:flutter/material.dart';
import '../components/glaya_card.dart';
import '../components/glaya_chip.dart';
import '../components/glaya_fab.dart';
import '../app_theme_glaya2.dart';
import '../widgets/glaya_hero_card.dart';

class HomeGlaya2 extends StatelessWidget {
  const HomeGlaya2({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GlayaTheme2.background,
      appBar: AppBar(
        title: const Text('Glaya'),
        elevation: 0,
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
        ],
      ),
      body: const SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hello, Jane',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    SizedBox(height: 10),
                    Text('Top picks for you',
                        style: TextStyle(fontSize: 14, color: Colors.black54)),
                    SizedBox(height: 14),
                    GlayaHeroCard(
                        title: 'Glow More, Pay Less',
                        subtitle:
                            'Exclusive offers just for your next booking.',
                        badge: 'New'),
                    SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        GlayaChip(label: 'Wellness', selected: true),
                        GlayaChip(label: 'HAIR'),
                        GlayaChip(label: 'Nails'),
                        GlayaChip(label: 'Face'),
                      ],
                    ),
                    SizedBox(height: 16),
                    GlayaCard(
                        title: 'Relaxing Massage',
                        subtitle: 'At your comfort',
                        imageUrl: 'https://picsum.photos/200'),
                    SizedBox(height: 12),
                    GlayaCard(
                        title: 'Hair Styling',
                        subtitle: 'Trendy looks',
                        imageUrl: 'https://picsum.photos/201'),
                    SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: const SizedBox(height: 96)),
          ],
        ),
      ),
      floatingActionButton: GlayaFAB(onTap: () {}),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(onPressed: () {}, icon: const Icon(Icons.home)),
              IconButton(onPressed: () {}, icon: const Icon(Icons.explore)),
              const SizedBox(width: 56),
              IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.chat_bubble_outline)),
              IconButton(
                  onPressed: () {}, icon: const Icon(Icons.person_outline)),
            ],
          ),
        ),
      ),
    );
  }
}
