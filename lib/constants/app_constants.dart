import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// App-wide constants for Moneo budgeting application
class AppConstants {
  // Private constructor to prevent instantiation
  AppConstants._();

  /// App Information
  static const String appName = 'Moneo';
  static const String appVersion = '1.0.0';

  /// Currency Settings
  static const String defaultCurrency = 'USD';
  static const String currencySymbol = '\$';
  static final NumberFormat currencyFormatter = NumberFormat.currency(
    locale: 'en_US',
    symbol: currencySymbol,
    decimalDigits: 2,
  );

  /// Theme Colors
  static const Color primaryBlue = Color(0xFF2196F3);
  static const Color primaryBlueDark = Color(0xFF1976D2);
  static const Color primaryBlueLight = Color(0xFF64B5F6);

  static const Color secondaryColor = Color(0xFF03DAC6);
  static const Color errorColor = Color(0xFFB00020);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color successColor = Color(0xFF4CAF50);

  static const Color surfaceColor = Color(0xFFFAFAFA);
  static const Color backgroundColor = Color(0xFFFFFFFF);
  static const Color cardColor = Color(0xFFFFFFFF);

  /// Dark Theme Colors
  static const Color darkPrimaryBlue = Color(0xFF64B5F6);
  static const Color darkSurfaceColor = Color(0xFF121212);
  static const Color darkBackgroundColor = Color(0xFF000000);
  static const Color darkCardColor = Color(0xFF1E1E1E);

  /// Text Colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFF9E9E9E);

  /// Dark Text Colors
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFB3B3B3);
  static const Color darkTextHint = Color(0xFF666666);

  /// Spacing and Dimensions
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;

  static const double borderRadius = 12.0;
  static const double borderRadiusSmall = 8.0;
  static const double borderRadiusLarge = 16.0;

  static const double elevationLow = 2.0;
  static const double elevationMedium = 4.0;
  static const double elevationHigh = 8.0;

  /// Animation Durations
  static const Duration animationDurationShort = Duration(milliseconds: 200);
  static const Duration animationDurationMedium = Duration(milliseconds: 300);
  static const Duration animationDurationLong = Duration(milliseconds: 500);

  /// Database Constants
  static const String databaseName = 'moneo_database.db';
  static const int databaseVersion = 1;

  /// Supabase Constants
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

  /// Transaction Types
  static const String transactionTypeIncome = 'income';
  static const String transactionTypeExpense = 'expense';

  /// Category Types
  static const String categoryTypeIncome = 'income';
  static const String categoryTypeExpense = 'expense';
  static const String categoryTypeSavings = 'savings';

  /// Recurring Transaction Frequencies
  static const String frequencyWeekly = 'weekly';
  static const String frequencyMonthly = 'monthly';

  /// Default Categories
  static const List<Map<String, dynamic>> defaultExpenseCategories = [
    {'name': 'Food & Dining', 'color': '#FF5722'},
    {'name': 'Transportation', 'color': '#9C27B0'},
    {'name': 'Shopping', 'color': '#E91E63'},
    {'name': 'Entertainment', 'color': '#673AB7'},
    {'name': 'Bills & Utilities', 'color': '#3F51B5'},
    {'name': 'Healthcare', 'color': '#009688'},
    {'name': 'Education', 'color': '#4CAF50'},
    {'name': 'Travel', 'color': '#FF9800'},
    {'name': 'Personal Care', 'color': '#795548'},
    {'name': 'Other', 'color': '#607D8B'},
  ];

  static const List<Map<String, dynamic>> defaultIncomeCategories = [
    {'name': 'Salary', 'color': '#4CAF50'},
    {'name': 'Freelance', 'color': '#8BC34A'},
    {'name': 'Investment', 'color': '#CDDC39'},
    {'name': 'Business', 'color': '#FFC107'},
    {'name': 'Other Income', 'color': '#FF9800'},
  ];

  static const List<Map<String, dynamic>> defaultSavingsCategories = [
    {'name': 'Emergency Fund', 'color': '#F44336'},
    {'name': 'Vacation', 'color': '#E91E63'},
    {'name': 'Investment', 'color': '#9C27B0'},
    {'name': 'Retirement', 'color': '#673AB7'},
    {'name': 'General Savings', 'color': '#3F51B5'},
  ];

  /// Validation Constants
  static const int maxWalletNameLength = 100;
  static const int maxCategoryNameLength = 50;
  static const int maxTransactionNotesLength = 500;
  static const int maxRecurringTransactionDescriptionLength = 200;

  static const double minTransactionAmount = 0.01;
  static const double maxTransactionAmount = 999999.99;

  /// UI Constants
  static const int maxPinnedWallets = 4;
  static const int recentTransactionsLimit = 10;
  static const int transactionsPageSize = 50;

  /// Date Formats
  static final DateFormat dateFormat = DateFormat('MMM dd, yyyy');
  static final DateFormat timeFormat = DateFormat('hh:mm a');
  static final DateFormat dateTimeFormat = DateFormat('MMM dd, yyyy hh:mm a');
  static final DateFormat monthYearFormat = DateFormat('MMMM yyyy');

  /// Greeting Messages
  static const List<String> morningGreetings = [
    'Good Morning!',
    'Rise and Shine!',
    'Good Morning, Sunshine!',
  ];

  static const List<String> afternoonGreetings = [
    'Good Afternoon!',
    'Hope your day is going well!',
    'Good Afternoon, Champion!',
  ];

  static const List<String> eveningGreetings = [
    'Good Evening!',
    'Hope you had a great day!',
    'Good Evening, Star!',
  ];

  /// Helper Methods

  /// Format currency amount to USD format
  static String formatCurrency(double amount) {
    return currencyFormatter.format(amount);
  }

  /// Get time-based greeting
  static String getTimeBasedGreeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return morningGreetings[DateTime.now().millisecond %
          morningGreetings.length];
    } else if (hour < 17) {
      return afternoonGreetings[DateTime.now().millisecond %
          afternoonGreetings.length];
    } else {
      return eveningGreetings[DateTime.now().millisecond %
          eveningGreetings.length];
    }
  }

  /// Convert hex color string to Color object
  static Color hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  /// Convert Color object to hex string
  static String colorToHex(Color color) {
    final int alpha = (color.a * 255.0).round() & 0xff;
    final int red = (color.r * 255.0).round() & 0xff;
    final int green = (color.g * 255.0).round() & 0xff;
    final int blue = (color.b * 255.0).round() & 0xff;
    final int argb = alpha << 24 | red << 16 | green << 8 | blue;
    return '#${argb.toRadixString(16).padLeft(8, '0').substring(2)}';
  }
}
