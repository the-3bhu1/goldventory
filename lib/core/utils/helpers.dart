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
}
