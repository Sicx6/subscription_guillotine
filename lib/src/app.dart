import 'package:flutter/material.dart';

import 'features/subscriptions/dashboard_screen.dart';
import 'util/theme_pallete.dart';

class SubscriptionGuillotineApp extends StatelessWidget {
  const SubscriptionGuillotineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Subscription Guillotine',
      theme: Pallete.lightTheme,
      darkTheme: Pallete.darkTheme,
      themeMode: ThemeMode.system,
      home: const DashboardScreen(),
    );
  }
}
