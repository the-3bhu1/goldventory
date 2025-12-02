import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'theme.dart';
import 'package:goldventory/app/routes.dart';
import 'package:goldventory/global/global_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Goldventory',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: GlobalScaffold.messengerKey,
      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}