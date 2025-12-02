import 'package:flutter/material.dart';

class GlobalScaffold {
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();
}

class GlobalState extends ChangeNotifier {

  bool isDarkMode = false;

  // Loading state
  bool _isLoading = false;

  // Bulk update mode flag
  bool _isBulkUpdating = false;
  bool get isBulkUpdating => _isBulkUpdating;

  void setBulkUpdating(bool value) {
    _isBulkUpdating = value;
    notifyListeners();
  }

  bool get isLoading => _isLoading;


  // Example method: toggle app theme
  void toggleTheme() {
    isDarkMode = !isDarkMode;
    notifyListeners(); // notifies all widgets listening to this provider

    // TODO: Persist theme preference using SharedPreferences or Hive
  }

  // Set loading state
  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }


  // Global threshold map (item-weight → threshold value)
  Map<String, int> globalThresholds = {};

  // Method to get threshold for a given key
  int getThreshold(String key) {
    return globalThresholds[key] ?? 5; // default threshold
  }

  // Method to set threshold for a given key
  void setThreshold(String key, int value) {
    globalThresholds[key] = value;
    notifyListeners();
  }

  void notifyThresholdChange() {
    notifyListeners();
  }

  // Method to check if below threshold
  bool isBelowThreshold(String key, int? quantity) {
    if (quantity == null) return false;
    final threshold = getThreshold(key);
    return quantity < threshold;
  }

  void clearThresholds() {
    globalThresholds.clear();
    notifyListeners();
  }
}