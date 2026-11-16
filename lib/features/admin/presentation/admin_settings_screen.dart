import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/config_providers.dart';

class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  ConsumerState<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Settings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Business'),
            Tab(text: 'Payment Gateways'),
            Tab(text: 'Currencies'),
            Tab(text: 'Location'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          BusinessSettingsTab(),
          PaymentGatewaysTab(),
          CurrenciesTab(),
          LocationSettingsTab(),
        ],
      ),
    );
  }
}

class BusinessSettingsTab extends ConsumerWidget {
  const BusinessSettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Business Settings',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          BusinessSettingsForm(),
        ],
      ),
    );
  }
}

class PaymentGatewaysTab extends ConsumerWidget {
  const PaymentGatewaysTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Gateways',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          PaymentGatewayForm(),
        ],
      ),
    );
  }
}

class CurrenciesTab extends ConsumerWidget {
  const CurrenciesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Currencies',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          CurrencyForm(),
        ],
      ),
    );
  }
}

class LocationSettingsTab extends ConsumerWidget {
  const LocationSettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Location Settings',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          LocationSettingsForm(),
        ],
      ),
    );
  }
}

// Business Settings Form
class BusinessSettingsForm extends ConsumerWidget {
  const BusinessSettingsForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(businessSettingsProvider);
    final notifier = ref.watch(businessSettingsNotifierProvider.notifier);

    return settingsAsync.when(
      data: (settings) {
        return Column(
          children: [
            _buildTextField(
              label: 'Business Name',
              value: settings['business_name'] ?? '',
              onChanged: (value) => notifier.updateSetting('business_name', value),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Currency',
              value: settings['currency'] ?? 'XAF',
              onChanged: (value) => notifier.updateSetting('currency', value),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Currency Symbol',
              value: settings['currency_symbol'] ?? 'FCFA',
              onChanged: (value) => notifier.updateSetting('currency_symbol', value),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Phone',
              value: settings['phone'] ?? '',
              onChanged: (value) => notifier.updateSetting('phone', value),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Email',
              value: settings['email_address'] ?? '',
              onChanged: (value) => notifier.updateSetting('email_address', value),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Tax Rate (%)',
              value: settings['tax'] ?? '0',
              onChanged: (value) => notifier.updateSetting('tax', value),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Admin Commission (%)',
              value: settings['admin_commission'] ?? '10',
              onChanged: (value) => notifier.updateSetting('admin_commission', value),
              keyboardType: TextInputType.number,
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildTextField({
    required String label,
    required String value,
    required Function(String) onChanged,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: TextEditingController(text: value),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      keyboardType: keyboardType ?? TextInputType.text,
      onChanged: onChanged,
    );
  }
}

class PaymentGatewayForm extends ConsumerWidget {
  const PaymentGatewayForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gatewaysAsync = ref.watch(paymentGatewaysProvider);
    final notifier = ref.watch(paymentGatewayNotifierProvider.notifier);

    return gatewaysAsync.when(
      data: (gateways) {
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: gateways.length,
          itemBuilder: (context, index) {
            final gateway = gateways[index];
            final values = gateway['mode'] == 'live'
                ? gateway['live_values']
                : gateway['test_values'];
            final isActive = gateway['is_active'] ?? false;

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          gateway['key_name'].toString().toUpperCase(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Switch(
                          value: isActive,
                          onChanged: (value) {
                            notifier.updateGateway(gateway['key_name'], {
                              ...values,
                              'status': value ? 1 : 0,
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (gateway['key_name'] == 'notchpay') ...[
                      _buildTextField(
                        label: 'API Key',
                        value: values?['api_key'] ?? '',
                        onChanged: (value) => notifier.updateGateway(
                          gateway['key_name'],
                          {...values, 'api_key': value},
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        label: 'Currency',
                        value: values?['currency'] ?? 'XAF',
                        onChanged: (value) => notifier.updateGateway(
                          gateway['key_name'],
                          {...values, 'currency': value},
                        ),
                      ),
                    ],
                    if (gateway['key_name'] == 'stripe') ...[
                      _buildTextField(
                        label: 'API Key',
                        value: values?['api_key'] ?? '',
                        onChanged: (value) => notifier.updateGateway(
                          gateway['key_name'],
                          {...values, 'api_key': value},
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        label: 'Published Key',
                        value: values?['published_key'] ?? '',
                        onChanged: (value) => notifier.updateGateway(
                          gateway['key_name'],
                          {...values, 'published_key': value},
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildTextField({
    required String label,
    required String value,
    required Function(String) onChanged,
  }) {
    return TextField(
      controller: TextEditingController(text: value),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged,
    );
  }
}

class CurrencyForm extends ConsumerWidget {
  const CurrencyForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currenciesAsync = ref.watch(currenciesProvider);
    final notifier = ref.watch(currencyNotifierProvider.notifier);

    return Column(
      children: [
        Row(
          children: [
            ElevatedButton(
              onPressed: () => notifier.refreshExchangeRates(),
              child: const Text('Refresh Exchange Rates'),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: () => _showAddCurrencyDialog(context, notifier),
              child: const Text('Add Currency'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        currenciesAsync.when(
          data: (currencies) {
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: currencies.length,
              itemBuilder: (context, index) {
                final currency = currencies[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(
                      '${currency['currency_code']} - ${currency['currency_symbol']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Rate: ${currency['exchange_rate']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showEditCurrencyDialog(
                            context,
                            notifier,
                            currency,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _showDeleteConfirmDialog(
                            context,
                            notifier,
                            currency['id'],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
        ),
      ],
    );
  }

  void _showAddCurrencyDialog(BuildContext context, CurrencyNotifier notifier) {
    final codeController = TextEditingController();
    final symbolController = TextEditingController();
    final rateController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Currency'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeController,
              decoration: const InputDecoration(labelText: 'Currency Code (e.g., USD)'),
            ),
            TextField(
              controller: symbolController,
              decoration: const InputDecoration(labelText: 'Symbol (e.g., \$)'),
            ),
            TextField(
              controller: rateController,
              decoration: const InputDecoration(labelText: 'Exchange Rate'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              notifier.addCurrency({
                'currencyCode': codeController.text.toUpperCase(),
                'currencySymbol': symbolController.text,
                'exchangeRate': double.tryParse(rateController.text) ?? 1.0,
              });
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditCurrencyDialog(
    BuildContext context,
    CurrencyNotifier notifier,
    Map<String, dynamic> currency,
  ) {
    final symbolController = TextEditingController(text: currency['currency_symbol']);
    final rateController = TextEditingController(text: currency['exchange_rate'].toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Currency'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: symbolController,
              decoration: const InputDecoration(labelText: 'Symbol'),
            ),
            TextField(
              controller: rateController,
              decoration: const InputDecoration(labelText: 'Exchange Rate'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              notifier.updateCurrency(currency['id'], {
                'currencySymbol': symbolController.text,
                'exchangeRate': double.tryParse(rateController.text) ?? 1.0,
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(
    BuildContext context,
    CurrencyNotifier notifier,
    String id,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Currency'),
        content: const Text('Are you sure you want to delete this currency?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              notifier.deleteCurrency(id);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class LocationSettingsForm extends ConsumerWidget {
  const LocationSettingsForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationAsync = ref.watch(locationSettingsProvider);
    final notifier = ref.watch(locationSettingsNotifierProvider.notifier);

    return locationAsync.when(
      data: (location) {
        return Column(
          children: [
            _buildTextField(
              label: 'Latitude',
              value: location['lat']?.toString() ?? '3.8480',
              onChanged: (value) {
                final lat = double.tryParse(value) ?? 3.8480;
                final lng = location['lng'] ?? 11.5021;
                notifier.updateLocation(lat, lng);
              },
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Longitude',
              value: location['lng']?.toString() ?? '11.5021',
              onChanged: (value) {
                final lng = double.tryParse(value) ?? 11.5021;
                final lat = location['lat'] ?? 3.8480;
                notifier.updateLocation(lat, lng);
              },
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            const Text(
              'Note: These coordinates define the default location for the business.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildTextField({
    required String label,
    required String value,
    required Function(String) onChanged,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: TextEditingController(text: value),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      keyboardType: keyboardType ?? TextInputType.text,
      onChanged: onChanged,
    );
  }
}
