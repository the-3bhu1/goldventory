import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:goldventory/app/routes.dart';
import 'package:goldventory/core/utils/helpers.dart';
import 'package:goldventory/core/widgets/responsive_layout.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime? _lastPressedAt;
  @override
  void initState() {
    super.initState();
    // Show a welcome snackbar for 3 seconds after the first frame when arriving at Dashboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Helpers.showSnackBar('Welcome Darshan!');
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastPressedAt == null ||
            now.difference(_lastPressedAt!) > const Duration(seconds: 2)) {
          _lastPressedAt = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        await SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          centerTitle: true,
          title: const Text(
            'Dashboard',
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Wrap(
                spacing: 24,
                runSpacing: 24,
                alignment: WrapAlignment.center,
                children: [
                  DashboardCard(
                    title: 'Inventory',
                    description: 'Track and manage your stock',
                    icon: Icons.inventory_2_outlined,
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.inventory),
                  ),
                  DashboardCard(
                    title: 'Reorder List',
                    description: 'Check low stock and reorder',
                    icon: Icons.shopping_cart_outlined,
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.reorder),
                  ),
                  DashboardCard(
                    title: 'Thresholds',
                    description: 'Set thresholds for each item individually',
                    icon: Icons.tune_outlined,
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.thresholds),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const DashboardCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  State<DashboardCard> createState() => _DashboardCardState();
}

class _DashboardCardState extends State<DashboardCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    // Unified width for both Light and Dark modes to match "outer rectangles"
    final double cardWidth =
        Responsive.isMobile(context) ? double.infinity : 300.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: cardWidth,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: theme.primaryColor.withValues(alpha: 0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 64,
                color: isLight ? theme.primaryColor : Colors.white,
              ),
              const SizedBox(height: 24),
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: Responsive.textSize(context, base: 22),
                  fontWeight: FontWeight.w700,
                  color: isLight ? theme.primaryColor : Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.description,
                style: TextStyle(
                  fontSize: Responsive.textSize(context, base: 14),
                  color: isLight
                      ? theme.primaryColor.withValues(alpha: 0.8)
                      : Colors.white.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
