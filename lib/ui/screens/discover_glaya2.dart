import 'package:flutter/material.dart';
import '../components/glaya_card.dart';
import '../app_theme_glaya2.dart';

class DiscoverGlaya2 extends StatelessWidget {
  const DiscoverGlaya2({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GlayaTheme2.background,
      appBar: AppBar(
        title: const Text('Discover'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Explore services', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisExtent: 180, crossAxisSpacing: 12, mainAxisSpacing: 12),
                  itemCount: 8,
                  itemBuilder: (context, index) => GlayaCard(
                    title: 'Service ${index + 1}',
                    subtitle: 'Quick description',
                    imageUrl: 'https://picsum.photos/20$index',
                    onTap: () {},
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
