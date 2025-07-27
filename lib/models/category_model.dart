import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'database.dart';

// Extension methods for Category model
extension CategoryExtensions on Category {
  /// Get the color as a Flutter Color object
  Color get colorValue {
    try {
      return Color(int.parse(color.replaceFirst('#', '0xFF')));
    } catch (e) {
      return const Color(0xFF2196F3); // Default blue color
    }
  }

  /// Format monthly budget as USD currency
  String get formattedBudget {
    if (monthlyBudget == null) return 'No budget set';
    return '\$${monthlyBudget!.toStringAsFixed(2)}';
  }

  /// Check if category is income type
  bool get isIncome => type == 'income';

  /// Check if category is expense type
  bool get isExpense => type == 'expense';

  /// Check if category is savings type
  bool get isSavings => type == 'savings';

  /// Get category type display name
  String get typeDisplayName {
    switch (type) {
      case 'income':
        return 'Income';
      case 'expense':
        return 'Expense';
      case 'savings':
        return 'Savings';
      default:
        return 'Unknown';
    }
  }

  /// Check if category has budget set
  bool get hasBudget => monthlyBudget != null && monthlyBudget! > 0;

  /// Calculate budget progress percentage
  double getBudgetProgress(double spent) {
    if (!hasBudget) return 0.0;
    return (spent / monthlyBudget!).clamp(0.0, 1.0);
  }

  /// Check if budget is exceeded
  bool isBudgetExceeded(double spent) {
    if (!hasBudget) return false;
    return spent > monthlyBudget!;
  }

  /// Get remaining budget amount
  double getRemainingBudget(double spent) {
    if (!hasBudget) return 0.0;
    return (monthlyBudget! - spent).clamp(0.0, monthlyBudget!);
  }
}

// Category companion extensions for easier creation
extension CategoryCompanionExtensions on CategoriesCompanion {
  /// Create a new category companion with required fields
  static CategoriesCompanion create({
    required String name,
    required String type,
    double? monthlyBudget,
    String color = '#2196F3',
  }) {
    return CategoriesCompanion.insert(
      name: name,
      type: type,
      monthlyBudget:
          monthlyBudget != null ? Value(monthlyBudget) : const Value.absent(),
      color: Value(color),
    );
  }

  /// Create an update companion for category
  static CategoriesCompanion update({
    String? name,
    String? type,
    double? monthlyBudget,
    String? color,
  }) {
    return CategoriesCompanion(
      name: name != null ? Value(name) : const Value.absent(),
      type: type != null ? Value(type) : const Value.absent(),
      monthlyBudget:
          monthlyBudget != null ? Value(monthlyBudget) : const Value.absent(),
      color: color != null ? Value(color) : const Value.absent(),
    );
  }
}

// Category type enum for better type safety
enum CategoryType {
  income('income'),
  expense('expense'),
  savings('savings');

  const CategoryType(this.value);
  final String value;

  static CategoryType fromString(String value) {
    return CategoryType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => CategoryType.expense,
    );
  }

  String get displayName {
    switch (this) {
      case CategoryType.income:
        return 'Income';
      case CategoryType.expense:
        return 'Expense';
      case CategoryType.savings:
        return 'Savings';
    }
  }

  IconData get icon {
    switch (this) {
      case CategoryType.income:
        return Icons.trending_up;
      case CategoryType.expense:
        return Icons.trending_down;
      case CategoryType.savings:
        return Icons.savings;
    }
  }
}
