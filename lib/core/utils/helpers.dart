import 'package:flutter/material.dart';
import '../../global/global_state.dart';

class Helpers {
  static void showSnackBar(String message, {Color? backgroundColor}) {
    final messenger = GlobalScaffold.messengerKey.currentState;
    if (messenger == null) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.black),
        ),
        backgroundColor: backgroundColor ?? const Color(0xFFB8E0D2),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  static String formatNumber(num value) {
    return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
  }

  static void unfocus(BuildContext context) {
    FocusScope.of(context).unfocus();
  }

  /// Safely parses a Firestore-safe numeric key (e.g. '2_5' -> 2.5)
  static num safeNum(String raw) {
    // Firestore-safe keys replace '.' with '_'
    final normalized = raw.replaceAll('_', '.');
    return num.tryParse(normalized) ?? double.infinity;
  }

  static bool areListsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final sortedA = [...a]; // ..sort();
    final sortedB = [...b]; // ..sort();
    for (int i = 0; i < a.length; i++) {
      if (sortedA[i] != sortedB[i]) return false;
    }
    return true;
  }

  static List<String> extractSubItems(Map<String, dynamic> itemMap) {
    return itemMap.keys
        .where((k) => k != 'shared' && !k.startsWith('__'))
        .toList()
      ..sort();
  }
}
