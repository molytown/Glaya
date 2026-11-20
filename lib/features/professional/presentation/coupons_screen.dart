import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/text_styles.dart';
import '../../../../shared/widgets/bottom_nav.dart';
import '../../auth/presentation/providers/auth_notifier.dart';

class CouponsScreen extends ConsumerStatefulWidget {
  const CouponsScreen({super.key});

  @override
  ConsumerState<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends ConsumerState<CouponsScreen> {
  List<Map<String, dynamic>> _coupons = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCoupons();
  }

  Future<void> _loadCoupons() async {
    try {
      final response = await ApiService.dio.get('/coupons');
      setState(() => _coupons =
          (response.data['data'] as List).cast<Map<String, dynamic>>());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load coupons: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteCoupon(String id) async {
    try {
      await ApiService.dio.delete('/coupons/$id');
      await _loadCoupons();
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
        title: const Text('Coupons'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _coupons.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.discount_outlined,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('No coupons yet',
                          style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => _showAddDialog(),
                        child: const Text('Create Coupon'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _coupons.length,
                  itemBuilder: (context, index) {
                    final coupon = _coupons[index];
                    final expiryDate = DateTime.tryParse(
                        coupon['expiryDate'] as String? ?? '');
                    final isActive = expiryDate != null &&
                        expiryDate.isAfter(DateTime.now());
                    final usageCount = coupon['usageCount'] as int? ?? 0;
                    final maxUsage = coupon['maxUsage'] as int?;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isActive
                                ? GlayaColors.berry.withValues(alpha: 0.1)
                                : Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.confirmation_number,
                            color: isActive ? GlayaColors.berry : Colors.grey,
                          ),
                        ),
                        title: Text(
                          coupon['code'] as String? ?? 'CODE',
                          style: GlayaTextStyles.titleMedium(),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${coupon['discountAmount'] ?? 0}${coupon['discountType'] == 'percent' ? '%' : ' off'}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (expiryDate != null)
                              Text(
                                'Expires: ${DateFormat('MMM d, yyyy').format(expiryDate)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            if (maxUsage != null)
                              Text(
                                'Used: $usageCount/$maxUsage',
                                style: const TextStyle(fontSize: 12),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? GlayaColors.success.withValues(alpha: 0.1)
                                    : Colors.grey.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isActive ? 'Active' : 'Expired',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isActive
                                      ? GlayaColors.success
                                      : Colors.grey,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: GlayaColors.error),
                              onPressed: () =>
                                  _deleteCoupon(coupon['id'] as String),
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
    final codeController = TextEditingController();
    final discountController = TextEditingController();
    final expiryController = TextEditingController();
    final maxUsageController = TextEditingController();
    final minAmountController = TextEditingController();
    String discountType = 'percent';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Coupon'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(labelText: 'Coupon Code'),
                  textCapitalization: TextCapitalization.characters,
                ),
                TextField(
                  controller: discountController,
                  decoration:
                      const InputDecoration(labelText: 'Discount Amount'),
                  keyboardType: TextInputType.number,
                ),
                DropdownButtonFormField<String>(
                  initialValue: discountType,
                  decoration: const InputDecoration(labelText: 'Discount Type'),
                  items: const [
                    DropdownMenuItem(value: 'percent', child: Text('Percent')),
                    DropdownMenuItem(
                        value: 'fixed', child: Text('Fixed Amount')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => discountType = value!),
                ),
                TextField(
                  controller: expiryController,
                  decoration: const InputDecoration(
                      labelText: 'Expiry Date (YYYY-MM-DD)'),
                  keyboardType: TextInputType.datetime,
                ),
                TextField(
                  controller: maxUsageController,
                  decoration:
                      const InputDecoration(labelText: 'Max Usage (optional)'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: minAmountController,
                  decoration: const InputDecoration(
                      labelText: 'Min Order Amount (optional)'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                try {
                  final data = {
                    'code': codeController.text.toUpperCase(),
                    'discountAmount': double.parse(discountController.text),
                    'discountType': discountType,
                    'expiryDate': expiryController.text,
                  };
                  if (maxUsageController.text.isNotEmpty) {
                    data['maxUsage'] = int.parse(maxUsageController.text);
                  }
                  if (minAmountController.text.isNotEmpty) {
                    data['minAmount'] = double.parse(minAmountController.text);
                  }

                  await ApiService.dio.post('/coupons', data: data);
                  if (mounted) {
                    Navigator.pop(context);
                    await _loadCoupons();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Failed to create: ${e.toString()}')),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}
