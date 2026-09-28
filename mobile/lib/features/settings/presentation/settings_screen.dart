import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../settings/providers/settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.brightness_6_outlined, color: AppColors.secondary),
                  title: const Text('Theme'),
                  subtitle: const Text('Choose how the app looks'),
                  trailing: DropdownButton<ThemeMode>(
                    value: themeMode,
                    items: const [
                      DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                      DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                      DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        ref.read(themeModeProvider.notifier).setMode(v.name);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.info_outline, color: AppColors.primary),
                  title: Text('About'),
                ),
                ListTile(
                  dense: true,
                  leading: const SizedBox(width: 0),
                  title: const Text('App'),
                  trailing: Text('${AppConstants.appFullName} ${AppConstants.appVersion}', style: Theme.of(context).textTheme.bodySmall),
                ),
                ListTile(
                  dense: true,
                  leading: const SizedBox(width: 0),
                  title: const Text('Server'),
                  trailing: Text(AppConstants.baseUrl, style: Theme.of(context).textTheme.bodySmall),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
