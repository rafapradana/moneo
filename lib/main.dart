import 'package:flutter/material.dart';
import 'constants/app_constants.dart';
import 'constants/app_theme.dart';

void main() {
  runApp(const MoneoApp());
}

class MoneoApp extends StatelessWidget {
  const MoneoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const PlaceholderHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Placeholder home page for initial setup
/// This will be replaced with proper navigation and screens in later tasks
class PlaceholderHomePage extends StatelessWidget {
  const PlaceholderHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Moneo')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              AppConstants.getTimeBasedGreeting(),
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: AppConstants.paddingLarge),
            Text(
              'Welcome to ${AppConstants.appName}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppConstants.paddingMedium),
            Text(
              'Your personal finance tracking app',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppConstants.paddingXLarge),
            Text(
              AppConstants.formatCurrency(1234.56),
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: AppConstants.primaryBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppConstants.paddingSmall),
            Text(
              'Sample currency formatting',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
