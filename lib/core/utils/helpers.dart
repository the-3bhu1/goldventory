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
        .toList();
  }

  static String? getSubItemImage(String category, String subItem) {
    final clean = subItem.trim().toUpperCase();

    // 1. Teeka Chains (Image 1, Image 2, etc)
    if (clean.startsWith('IMAGE ')) {
      final num = clean.replaceAll('IMAGE ', '');
      return 'assets/images/teeka/image_$num.png';
    }

    // 2. Jhumkis
    if (category.toUpperCase() == 'JHUMKIS') {
      final map = {
        'LOOSE BALL': 'loose_ball.png',
        'LB 2 STEP': 'loose_ball.png',
        'LB 3 STEP': 'loose_ball.png',
        'ATTACH BALL': 'attach_ball.png',
        'AB 2 STEP': 'attach_ball.png',
        'AB 3 STEP': 'attach_ball.png',
        '3 LINE': '3_line.png',
        '3 LINE BELL': '3_line_bell.png',
        'NAKAS': 'nakas.png',
        'NAKAS WITH BELL': 'nakas_with_bell.png',
        'GRAPE': 'grape.png',
        'PANJRA': 'panjra.png',
        'SPIRAL': 'spiral.png',
        'SPIRAL 2 STEP': 'spiral.png',
      };
      final file = map[clean];
      if (file != null) return 'assets/images/jhumkis/$file';
    }

    return null;
  }
}
