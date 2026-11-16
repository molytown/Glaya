import 'package:flutter/material.dart';
import '../theme/colors.dart';

class DepositInvoiceForm extends StatefulWidget {
  final Function(bool requireDeposit, double? amount) onConfirm;
  final double? suggestedAmount;

  const DepositInvoiceForm({
    super.key,
    required this.onConfirm,
    this.suggestedAmount,
  });

  @override
  State<DepositInvoiceForm> createState() => _DepositInvoiceFormState();
}

class _DepositInvoiceFormState extends State<DepositInvoiceForm> {
  final _amountController = TextEditingController();
  bool _requireDeposit = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.suggestedAmount != null) {
      _amountController.text = widget.suggestedAmount.toString();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _handleConfirm() {
    double? amount;
    if (_requireDeposit) {
      amount = double.tryParse(_amountController.text);
      if (amount == null || amount <= 0) {
        setState(() => _error = 'Please enter a valid deposit amount');
        return;
      }
    }
    
    widget.onConfirm(_requireDeposit, amount);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
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
                  'Deposit Invoice',
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

            // Deposit toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Require Deposit?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: GlayaColors.textPrimary,
                  ),
                ),
                Switch(
                  value: _requireDeposit,
                  onChanged: (value) {
                    setState(() {
                      _requireDeposit = value;
                      _error = null;
                    });
                  },
                  activeTrackColor: GlayaColors.berry,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Amount field
            if (_requireDeposit) ...[
              const Text(
                'Deposit Amount',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: GlayaColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: 'Enter amount',
                  prefixText: 'XAF ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: GlayaColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: GlayaColors.berry),
                  ),
                  errorText: _error,
                ),
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 8),
              Text(
                'This amount will be required as a deposit to confirm the booking.',
                style: TextStyle(
                  fontSize: 11,
                  color: GlayaColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: GlayaColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: GlayaColors.success,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No deposit required. User can proceed with booking confirmation.',
                        style: TextStyle(
                          fontSize: 12,
                          color: GlayaColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Confirm button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlayaColors.berry,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _requireDeposit ? 'Send Deposit Invoice' : 'Confirm No Deposit',
                  style: const TextStyle(
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