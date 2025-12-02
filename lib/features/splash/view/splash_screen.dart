import 'dart:async';
import 'package:flutter/material.dart';
import 'package:goldventory/app/routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // Define a light background color
  final Color _backgroundColor = Colors.white;

  @override
  void initState() {
    super.initState();

    // Show PNG logo for 5 seconds, then navigate to next screen
    Timer(const Duration(seconds: 5), _checkLoginStatus);
  }

  void _checkLoginStatus() {
    // Skip login — go straight to dashboard
    Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
  }

  @override
  Widget build(BuildContext context) {
    final double logoWidth = MediaQuery.of(context).size.width * 1;

    return Scaffold(
      backgroundColor: _backgroundColor, // apply light bg to entire screen
      body: Center(
        child: Container(
          color: _backgroundColor, // ensure PNG logo has same bg
          child: Image.asset(
            'assets/images/logo.png',
            width: logoWidth,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}