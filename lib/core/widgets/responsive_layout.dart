

import 'package:flutter/material.dart';

/// Utility class for handling responsive sizing, spacing, and font scaling
class Responsive {
  /// Determines if the current device is a tablet (e.g. iPad)
  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide >= 600;

  /// Determines if the current device is a mobile device
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide < 600;

  /// Returns a responsive width for table cells or widgets based on screen size
  static double cellWidth(BuildContext context, {required double base}) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1200) return base * 1.4; // large tablets or desktop
    if (width >= 800) return base * 1.2; // normal tablets
    return base; // phones
  }

  /// Returns a responsive text size scaling based on device width
  static double textSize(BuildContext context, {required double base}) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1200) return base * 1.3;
    if (width >= 800) return base * 1.15;
    return base;
  }

  /// Provides consistent screen padding depending on device size
  static EdgeInsets screenPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1200) return const EdgeInsets.symmetric(horizontal: 48);
    if (width >= 800) return const EdgeInsets.symmetric(horizontal: 32);
    return const EdgeInsets.symmetric(horizontal: 16);
  }

  /// Returns a responsive height for table rows or cards
  static double rowHeight(BuildContext context, {required double base}) {
    final height = MediaQuery.of(context).size.height;
    if (height >= 1000) return base * 1.3;
    if (height >= 700) return base * 1.15;
    return base;
  }
}

/// A layout widget that switches between mobile and tablet layouts
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget tablet;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    required this.tablet,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 800) {
          return tablet;
        } else {
          return mobile;
        }
      },
    );
  }
}