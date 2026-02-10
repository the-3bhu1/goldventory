import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:goldventory/features/inventory/view_model/inventory_view_model.dart';
import 'package:provider/provider.dart';

import 'global/global_state.dart';
import 'app/app.dart';
import 'firebase_options.dart';
import 'core/services/database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final dbService = DatabaseService();
  await dbService.init();

  // Load state
  final globalState = GlobalState(databaseService: dbService);
  await globalState.loadThresholds();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: dbService),
        ChangeNotifierProvider(
          create: (context) => InventoryViewModel(context),
        ),
        ChangeNotifierProvider.value(
          value: globalState,
        ),
      ],
      child: const MyApp(),
    ),
  );
}
