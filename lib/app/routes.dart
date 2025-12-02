import 'package:flutter/material.dart';
import '../features/splash/view/splash_screen.dart';
import '../features/inventory/view/inventory_screen.dart';
import '../features/inventory/view/items/round_matil_screen.dart';
import '../features/inventory/view/items/gajje_matil_screen.dart';
import '../features/inventory/view/reorder_screen.dart';
import '../features/dashboard/view/dashboard_screen.dart';
import '../features/inventory/view/orders_screen.dart';

class AppRoutes {
  static const splash = '/';
  static const dashboard = '/dashboard';
  static const inventory = '/inventory';
  static const roundMatil = '/roundMatil';
  static const gajjeMatil = '/gajjeMatil';
  static const reorder = '/reorder';
  static const orders = '/orders';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case dashboard:
        return MaterialPageRoute(builder: (_) => const DashboardScreen());
      case inventory:
        return MaterialPageRoute(builder: (_) => const InventoryScreen());
      case roundMatil:
        return MaterialPageRoute(builder: (_) => const RoundMatilScreen());
      case gajjeMatil:
        return MaterialPageRoute(builder: (_) => const GajjeMatilScreen());
      case reorder:
        return MaterialPageRoute(builder: (_) => const ReorderScreen());
      case orders:
        return MaterialPageRoute(builder: (_) => const OrdersScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Page not found')),
          ),
        );
    }
  }
}
