import 'package:flutter/material.dart';
import '../features/splash/view/splash_screen.dart';
import '../features/inventory/view/inventory_screen.dart';
import '../features/inventory/view/reorder_screen.dart';
import '../features/dashboard/view/dashboard_screen.dart';
import '../features/inventory/view/orders_screen.dart';
import '../features/settings/settings_page.dart';

class AppRoutes {
  static const splash = '/';
  static const dashboard = '/dashboard';
  static const inventory = '/inventory';
  static const reorder = '/reorder';
  static const orders = '/orders';
  static const settings = '/settings';

  static Route<dynamic> generateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case dashboard:
        return MaterialPageRoute(builder: (_) => const DashboardScreen());
      case inventory:
        return MaterialPageRoute(builder: (_) => const InventoryScreen());
      case reorder:
        return MaterialPageRoute(builder: (_) => const ReorderScreen());
      case orders:
        return MaterialPageRoute(builder: (_) => const OrdersScreen());
      case settings:
        return MaterialPageRoute(builder: (_) => const SettingsPage());
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Page not found')),
          ),
        );
    }
  }
}
