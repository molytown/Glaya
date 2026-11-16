import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/currency_service.dart';

final currencyProvider = Provider<Map<String, dynamic>>((ref) {
  const currencyCode = 'XAF'; // Default currency
  final symbol = CurrencyService.getCurrencySymbol(currencyCode);
  return {'code': currencyCode, 'symbol': symbol};
});

class CurrencyDisplay extends ConsumerWidget {
  final double amount;
  final String? currencyCode;
  final String? currencySymbol;
  final TextStyle? style;
  final int decimalDigits;

  const CurrencyDisplay({
    super.key,
    required this.amount,
    this.currencyCode,
    this.currencySymbol,
    this.style,
    this.decimalDigits = 2,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    final code = currencyCode ?? currency['code'] ?? 'XAF';
    final formatted = CurrencyService().formatPrice(amount, code);
    return Text(
      formatted,
      style: style,
    );
  }
}

class CurrencyConverter extends ConsumerStatefulWidget {
  final double amount;
  final String fromCurrency;
  final String toCurrency;
  final Function(double?) onConverted;

  const CurrencyConverter({
    super.key,
    required this.amount,
    required this.fromCurrency,
    required this.toCurrency,
    required this.onConverted,
  });

  @override
  ConsumerState<CurrencyConverter> createState() => _CurrencyConverterState();
}

class _CurrencyConverterState extends ConsumerState<CurrencyConverter> {
  bool _isConverting = false;
  double? _convertedAmount;

  @override
  void initState() {
    super.initState();
    if (widget.fromCurrency != widget.toCurrency) {
      _convert();
    } else {
      _convertedAmount = widget.amount;
      widget.onConverted(widget.amount);
    }
  }

  Future<void> _convert() async {
    setState(() {
      _isConverting = true;
    });

    final conversion = await CurrencyService().convertPriceTo(
      widget.amount,
      widget.fromCurrency,
      widget.toCurrency,
    );

    setState(() {
      _isConverting = false;
      _convertedAmount = conversion.converted;
    });

    widget.onConverted(conversion.converted);
  }

  @override
  Widget build(BuildContext context) {
    if (_isConverting) {
      return const CircularProgressIndicator();
    }

    if (_convertedAmount == null) {
      return Text(
        '${widget.amount} ${widget.fromCurrency}',
        style: const TextStyle(color: Colors.grey),
      );
    }

    return Text(
      '${_convertedAmount!.toStringAsFixed(2)} ${widget.toCurrency}',
      style: const TextStyle(fontWeight: FontWeight.bold),
    );
  }
}

class CurrencySelector extends ConsumerWidget {
  final String selectedCurrency;
  final Function(String) onCurrencyChanged;

  const CurrencySelector({
    super.key,
    required this.selectedCurrency,
    required this.onCurrencyChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencies = ref.watch(currenciesProvider);

    return DropdownButtonFormField<String>(
      initialValue: selectedCurrency,
      decoration: const InputDecoration(
        labelText: 'Currency',
        border: OutlineInputBorder(),
      ),
      items: currencies.map((currency) {
        return DropdownMenuItem<String>(
          value: currency['currency_code'],
          child: Text(
            '${currency['currency_code']} - ${currency['currency_symbol']}',
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          onCurrencyChanged(value);
        }
      },
    );
  }
}

final currenciesProvider = Provider<List<Map<String, dynamic>>>((ref) {
  return CurrencyService.getCurrencies();
});
