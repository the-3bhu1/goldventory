// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:goldventory/app/routes.dart';
import 'package:goldventory/core/utils/helpers.dart';
import 'package:goldventory/core/widgets/responsive_layout.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => exit(0),
        ),
        title: const Text(
          'Dashboard',
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Colors.grey[300],
            height: 1,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(48.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: Wrap(
              spacing: 32,
              runSpacing: 32,
              alignment: WrapAlignment.center,
              children: [
                DashboardCard(
                  title: 'Inventory',
                  description: 'Track and manage your stock',
                  icon: Icons.inventory_2_outlined,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.inventory),
                ),
                DashboardCard(
                  title: 'Reorder List',
                  description: 'Check low stock and reorder',
                  icon: Icons.shopping_cart,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.reorder),
                ),
                DashboardCard(
                  title: 'Settings',
                  description: 'App configurations and preferences',
                  icon: Icons.settings,
                  onTap: () => Helpers.showSnackBar('Settings page coming soon!'),
                ),
              ],
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
    final cardWidth = Responsive.isTablet(context) ? 300.0 : 250.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: cardWidth,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: theme.cardColor,
              width: 3,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: _isHovered ? 1.1 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.icon,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: Responsive.textSize(context, base: 22),
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.description,
                  style: TextStyle(
                    fontSize: Responsive.textSize(context, base: 16),
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
