import 'package:flutter/material.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.dark_mode_outlined),
                  title: Text('Appearance'),
                  subtitle: Text('Follows your device theme'),
                ),
                Divider(
                  height: 1,
                  indent: 56,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                const ListTile(
                  leading: Icon(Icons.lock_outline),
                  title: Text('Private by design'),
                  subtitle:
                      Text('Receipts and subscriptions stay on this device'),
                ),
              ],
            ),
          ),
        ],
      );
}
