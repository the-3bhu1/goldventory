import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:goldventory/global/global_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final globalState = Provider.of<GlobalState>(context);
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
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
            activeColor: theme.primaryColor,
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'About',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
              ),
            ),
          ),
          const ListTile(
            title: Text('Version'),
            subtitle: Text('1.0.0+1'),
            leading: Icon(Icons.info_outline),
          ),
          const ListTile(
            title: Text('Developer'),
            subtitle: Text('Built for Darshan Gold'),
            leading: Icon(Icons.code),
          ),
        ],
      ),
    );
  }
}
