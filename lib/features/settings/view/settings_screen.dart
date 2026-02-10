import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:goldventory/global/global_state.dart';
import 'package:goldventory/core/services/database_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final globalState = Provider.of<GlobalState>(context);
    final dbService = Provider.of<DatabaseService>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Appearance',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Toggle between light and dark themes'),
            secondary: Icon(
              globalState.isDarkMode ? Icons.dark_mode : Icons.light_mode,
              color: theme.primaryColor,
            ),
            value: globalState.isDarkMode,
            onChanged: (value) {
              globalState.toggleTheme();
            },
            activeThumbColor:
                theme.floatingActionButtonTheme.foregroundColor ?? Colors.white,
            activeTrackColor: theme.primaryColor,
          ),
          const Divider(),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'About',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
              ),
            ),
          ),
          ListTile(
            title: const Text('Version'),
            subtitle: const Text('1.0.0+1'),
            leading: Icon(
              Icons.info_outline,
              color: theme.primaryColor,
            ),
            onTap: () {
              dbService.recordVersionTap();
              if (dbService.isDevModeActive) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Developer Mode is active')),
                );
              }
            },
            onLongPress: () async {
              if (dbService.isDevModeActive) {
                await dbService.setDevModeActive(false);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Developer Mode deactivated')),
                  );
                }
              }
            },
          ),
          if (dbService.isDevModeActive) ...[
            const Divider(),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Developer Settings',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
            ),
            ListTile(
              title: const Text('Database Flavor'),
              subtitle: Text(dbService.flavor == DatabaseFlavor.prod
                  ? 'Production (Live Data)'
                  : 'Development (Test Data)'),
              leading: Icon(
                dbService.flavor == DatabaseFlavor.prod
                    ? Icons.dvr
                    : Icons.bug_report,
                color: theme.primaryColor,
              ),
              trailing: Switch(
                value: dbService.flavor == DatabaseFlavor.dev,
                onChanged: (isDev) async {
                  await dbService.setFlavor(
                      isDev ? DatabaseFlavor.dev : DatabaseFlavor.prod);
                  // reload thresholds to reflect flavor change
                  await globalState.loadThresholds();
                },
              ),
            ),
          ],
          ListTile(
            title: Text('Developer'),
            subtitle: Text('Built for Darshan Gold'),
            leading: Icon(
              Icons.code,
              color: theme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
