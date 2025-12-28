import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:goldventory/features/inventory/view_model/inventory_view_model.dart';
import 'package:provider/provider.dart';
import 'core/services/threshold_service.dart';
import 'features/settings/settings_view_model.dart';
import 'global/global_state.dart';
import 'app/app.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => InventoryViewModel(context),
        ),
        ChangeNotifierProvider(
          create: (_) => GlobalState()..loadThresholds(),
        ),
        // SettingsViewModel is scoped to SettingsPage, removed from global providers
        Provider(
          create: (_) => ThresholdService(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}