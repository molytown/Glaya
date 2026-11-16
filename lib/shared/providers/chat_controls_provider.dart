import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatControlsState {
  final DateTime? selectedDate;
  final String? selectedTime;
  final bool requireDeposit;
  final double? depositAmount;
  final bool showTimePicker;
  final bool showDepositForm;
  final bool isSubmitting;
  final String? error;

  const ChatControlsState({
    this.selectedDate,
    this.selectedTime,
    this.requireDeposit = false,
    this.depositAmount,
    this.showTimePicker = false,
    this.showDepositForm = false,
    this.isSubmitting = false,
    this.error,
  });

  ChatControlsState copyWith({
    DateTime? selectedDate,
    String? selectedTime,
    bool? requireDeposit,
    double? depositAmount,
    bool? showTimePicker,
    bool? showDepositForm,
    bool? isSubmitting,
    String? error,
  }) {
    return ChatControlsState(
      selectedDate: selectedDate ?? this.selectedDate,
      selectedTime: selectedTime ?? this.selectedTime,
      requireDeposit: requireDeposit ?? this.requireDeposit,
      depositAmount: depositAmount ?? this.depositAmount,
      showTimePicker: showTimePicker ?? this.showTimePicker,
      showDepositForm: showDepositForm ?? this.showDepositForm,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error ?? this.error,
    );
  }
}

class ChatControlsNotifier extends StateNotifier<ChatControlsState> {
  ChatControlsNotifier() : super(const ChatControlsState());

  void showTimePicker() {
    state = state.copyWith(showTimePicker: true, error: null);
  }

  void hideTimePicker() {
    state = state.copyWith(showTimePicker: false);
  }

  void selectDate(DateTime date) {
    state = state.copyWith(selectedDate: date);
  }

  void selectTime(String time) {
    state = state.copyWith(selectedTime: time);
  }

  void showDepositForm() {
    state = state.copyWith(showDepositForm: true, error: null);
  }

  void hideDepositForm() {
    state = state.copyWith(showDepositForm: false);
  }

  void toggleDeposit(bool required) {
    state = state.copyWith(requireDeposit: required);
  }

  void setDepositAmount(double amount) {
    state = state.copyWith(depositAmount: amount);
  }

  void setError(String error) {
    state = state.copyWith(error: error);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  void setSubmitting(bool submitting) {
    state = state.copyWith(isSubmitting: submitting);
  }

  void reset() {
    state = const ChatControlsState();
  }

  bool get hasValidTimeSelection {
    return state.selectedDate != null && state.selectedTime != null;
  }

  bool get hasValidDepositSelection {
    if (!state.requireDeposit) return true;
    return state.depositAmount != null && state.depositAmount! > 0;
  }
}

final chatControlsProvider = StateNotifierProvider<ChatControlsNotifier, ChatControlsState>((ref) {
  return ChatControlsNotifier();
});
