import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/text_styles.dart';
import '../../../../shared/widgets/bottom_nav.dart';
import '../../auth/presentation/providers/auth_notifier.dart';

class PromotionsScreen extends ConsumerStatefulWidget {
  const PromotionsScreen({super.key});

  @override
  ConsumerState<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends ConsumerState<PromotionsScreen> {
  List<Map<String, dynamic>> _promotions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPromotions();
  }

  Future<void> _loadPromotions() async {
    try {
      final response = await ApiService.dio.get('/promotions');
      setState(() => _promotions = (response.data['data'] as List).cast<Map<String, dynamic>>());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load promotions: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deletePromotion(String id) async {
    try {
      await ApiService.dio.delete('/promotions/$id');
      await _loadPromotions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Promotions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _promotions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_offer_outlined, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('No promotions yet', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => _showAddDialog(),
                        child: const Text('Create Promotion'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _promotions.length,
                  itemBuilder: (context, index) {
                    final promotion = _promotions[index];
                    final startDate = DateTime.tryParse(promotion['startDate'] as String? ?? '');
                    final endDate = DateTime.tryParse(promotion['endDate'] as String? ?? '');
                    final isActive = endDate != null && endDate.isAfter(DateTime.now());
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isActive ? GlayaColors.berry.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.local_offer,
                            color: isActive ? GlayaColors.berry : Colors.grey,
                          ),
                        ),
                        title: Text(
                          promotion['title'] as String? ?? 'Promotion',
                          style: GlayaTextStyles.titleMedium(),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${promotion['discountPercent'] ?? 0}% off',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (startDate != null && endDate != null)
                              Text(
                                '${DateFormat('MMM d').format(startDate)} - ${DateFormat('MMM d, yyyy').format(endDate)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isActive ? GlayaColors.success.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isActive ? 'Active' : 'Expired',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isActive ? GlayaColors.success : Colors.grey,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: GlayaColors.error),
                              onPressed: () => _deletePromotion(promotion['id'] as String),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      bottomNavigationBar: user?.role == 'customer' 
          ? null 
          : GlayaBottomNav(
              currentIndex: 0,
              userRole: user?.role,
            ),
    );
  }

  void _showAddDialog() {
    final titleController = TextEditingController();
    final discountController = TextEditingController();
    final startDateController = TextEditingController();
    final endDateController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Promotion'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: discountController,
                decoration: const InputDecoration(labelText: 'Discount Percent (0-100)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: startDateController,
                decoration: const InputDecoration(labelText: 'Start Date (YYYY-MM-DD)'),
                keyboardType: TextInputType.datetime,
              ),
              TextField(
                controller: endDateController,
                decoration: const InputDecoration(labelText: 'End Date (YYYY-MM-DD)'),
                keyboardType: TextInputType.datetime,
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              try {
                await ApiService.dio.post('/promotions', data: {
                  'title': titleController.text,
                  'discountPercent': int.parse(discountController.text),
                  'startDate': startDateController.text,
                  'endDate': endDateController.text,
                  'description': descriptionController.text,
                });
                if (mounted) {
                  Navigator.pop(context);
                  await _loadPromotions();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to create: ${e.toString()}')),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
