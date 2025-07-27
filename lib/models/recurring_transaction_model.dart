import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'database.dart';

// Extension methods for RecurringTransaction model
extension RecurringTransactionExtensions on RecurringTransaction {
  /// Format amount as USD currency
  String get formattedAmount {
    return '\$${amount.toStringAsFixed(2)}';
  }

  /// Format amount with sign (- for expense/savings)
  String get formattedAmountWithSign {
    return '-\$${amount.toStringAsFixed(2)}';
  }

  /// Check if recurring transaction is expense type
  bool get isExpense => type == 'expense';

  /// Check if recurring transaction is savings type
  bool get isSavings => type == 'savings';

  /// Get transaction type display name
  String get typeDisplayName {
    switch (type) {
      case 'expense':
        return 'Expense';
      case 'savings':
        return 'Savings';
      default:
        return 'Unknown';
    }
  }

  /// Check if recurring transaction is weekly
  bool get isWeekly => frequency == 'weekly';

  /// Check if recurring transaction is monthly
  bool get isMonthly => frequency == 'monthly';

  /// Get frequency display name
  String get frequencyDisplayName {
    switch (frequency) {
      case 'weekly':
        return 'Weekly';
      case 'monthly':
        return 'Monthly';
      default:
        return 'Unknown';
    }
  }

  /// Format next due date
  String get formattedNextDue {
    return DateFormat('MMM dd, yyyy').format(nextDue);
  }

  /// Format next due date and time
  String get formattedNextDueDateTime {
    return DateFormat('MMM dd, yyyy HH:mm').format(nextDue);
  }

  /// Check if recurring transaction is due today
  bool get isDueToday {
    final now = DateTime.now();
    return nextDue.year == now.year &&
        nextDue.month == now.month &&
        nextDue.day == now.day;
  }

  /// Check if recurring transaction is overdue
  bool get isOverdue {
    return isActive && nextDue.isBefore(DateTime.now());
  }

  /// Get days until next due date
  int get daysUntilDue {
    final now = DateTime.now();
    final difference = nextDue.difference(now);
    return difference.inDays;
  }

  /// Get relative time until next due date
  String get relativeNextDue {
    if (isOverdue) {
      final daysPast = DateTime.now().difference(nextDue).inDays;
      return daysPast == 0 ? 'Due today' : '$daysPast days overdue';
    }

    final daysUntil = daysUntilDue;
    if (daysUntil == 0) {
      return 'Due today';
    } else if (daysUntil == 1) {
      return 'Due tomorrow';
    } else if (daysUntil <= 7) {
      return 'Due in $daysUntil days';
    } else {
      return formattedNextDue;
    }
  }

  /// Calculate next due date based on frequency
  DateTime calculateNextDueDate() {
    switch (frequency) {
      case 'weekly':
        return nextDue.add(const Duration(days: 7));
      case 'monthly':
        return DateTime(
          nextDue.year,
          nextDue.month + 1,
          nextDue.day,
          nextDue.hour,
          nextDue.minute,
        );
      default:
        return nextDue;
    }
  }

  /// Get status display text
  String get statusText {
    if (!isActive) return 'Inactive';
    if (isOverdue) return 'Overdue';
    if (isDueToday) return 'Due Today';
    return 'Active';
  }

  /// Get the impact on wallet balance (always negative for recurring transactions)
  double get balanceImpact => -amount;
}

// RecurringTransaction companion extensions for easier creation
extension RecurringTransactionCompanionExtensions
    on RecurringTransactionsCompanion {
  /// Create a new recurring transaction companion with required fields
  static RecurringTransactionsCompanion create({
    required double amount,
    required String type,
    required int categoryId,
    required int walletId,
    required String frequency,
    required String description,
    DateTime? nextDue,
    bool isActive = true,
  }) {
    return RecurringTransactionsCompanion.insert(
      amount: amount,
      type: type,
      categoryId: categoryId,
      walletId: walletId,
      frequency: frequency,
      description: description,
      nextDue: nextDue ?? _calculateInitialNextDue(frequency),
      isActive: Value(isActive),
    );
  }

  /// Create an update companion for recurring transaction
  static RecurringTransactionsCompanion update({
    double? amount,
    String? type,
    int? categoryId,
    int? walletId,
    String? frequency,
    String? description,
    DateTime? nextDue,
    bool? isActive,
  }) {
    return RecurringTransactionsCompanion(
      amount: amount != null ? Value(amount) : const Value.absent(),
      type: type != null ? Value(type) : const Value.absent(),
      categoryId: categoryId != null ? Value(categoryId) : const Value.absent(),
      walletId: walletId != null ? Value(walletId) : const Value.absent(),
      frequency: frequency != null ? Value(frequency) : const Value.absent(),
      description:
          description != null ? Value(description) : const Value.absent(),
      nextDue: nextDue != null ? Value(nextDue) : const Value.absent(),
      isActive: isActive != null ? Value(isActive) : const Value.absent(),
    );
  }

  /// Calculate initial next due date based on frequency
  static DateTime _calculateInitialNextDue(String frequency) {
    final now = DateTime.now();
    switch (frequency) {
      case 'weekly':
        return now.add(const Duration(days: 7));
      case 'monthly':
        return DateTime(now.year, now.month + 1, now.day, now.hour, now.minute);
      default:
        return now;
    }
  }
}

// Recurring transaction type enum for better type safety
enum RecurringTransactionType {
  expense('expense'),
  savings('savings');

  const RecurringTransactionType(this.value);
  final String value;

  static RecurringTransactionType fromString(String value) {
    return RecurringTransactionType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => RecurringTransactionType.expense,
    );
  }

  String get displayName {
    switch (this) {
      case RecurringTransactionType.expense:
        return 'Expense';
      case RecurringTransactionType.savings:
        return 'Savings';
    }
  }
}

// Recurring transaction frequency enum
enum RecurringFrequency {
  weekly('weekly'),
  monthly('monthly');

  const RecurringFrequency(this.value);
  final String value;

  static RecurringFrequency fromString(String value) {
    return RecurringFrequency.values.firstWhere(
      (freq) => freq.value == value,
      orElse: () => RecurringFrequency.monthly,
    );
  }

  String get displayName {
    switch (this) {
      case RecurringFrequency.weekly:
        return 'Weekly';
      case RecurringFrequency.monthly:
        return 'Monthly';
    }
  }

  /// Get the duration for this frequency
  Duration get duration {
    switch (this) {
      case RecurringFrequency.weekly:
        return const Duration(days: 7);
      case RecurringFrequency.monthly:
        return const Duration(days: 30); // Approximate
    }
  }
}
