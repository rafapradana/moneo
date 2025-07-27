import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'database.dart';

// Extension methods for Transaction model
extension TransactionExtensions on Transaction {
  /// Format amount as USD currency
  String get formattedAmount {
    return '\$${amount.toStringAsFixed(2)}';
  }

  /// Format amount with sign (+ for income, - for expense)
  String get formattedAmountWithSign {
    final sign = isIncome ? '+' : '-';
    return '$sign\$${amount.toStringAsFixed(2)}';
  }

  /// Check if transaction is income type
  bool get isIncome => type == 'income';

  /// Check if transaction is expense type
  bool get isExpense => type == 'expense';

  /// Get transaction type display name
  String get typeDisplayName {
    switch (type) {
      case 'income':
        return 'Income';
      case 'expense':
        return 'Expense';
      default:
        return 'Unknown';
    }
  }

  /// Format transaction date as readable string
  String get formattedDate {
    return DateFormat('MMM dd, yyyy').format(transactionDate);
  }

  /// Format transaction date and time
  String get formattedDateTime {
    return DateFormat('MMM dd, yyyy HH:mm').format(transactionDate);
  }

  /// Format transaction time only
  String get formattedTime {
    return DateFormat('HH:mm').format(transactionDate);
  }

  /// Get relative time (e.g., "2 hours ago", "Yesterday")
  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(transactionDate);

    if (difference.inDays > 7) {
      return formattedDate;
    } else if (difference.inDays > 0) {
      return difference.inDays == 1
          ? 'Yesterday'
          : '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return difference.inHours == 1
          ? '1 hour ago'
          : '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return difference.inMinutes == 1
          ? '1 minute ago'
          : '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  /// Check if transaction occurred today
  bool get isToday {
    final now = DateTime.now();
    return transactionDate.year == now.year &&
        transactionDate.month == now.month &&
        transactionDate.day == now.day;
  }

  /// Check if transaction occurred this week
  bool get isThisWeek {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    return transactionDate.isAfter(startOfWeek);
  }

  /// Check if transaction occurred this month
  bool get isThisMonth {
    final now = DateTime.now();
    return transactionDate.year == now.year &&
        transactionDate.month == now.month;
  }

  /// Get the impact on wallet balance (positive for income, negative for expense)
  double get balanceImpact {
    return isIncome ? amount : -amount;
  }
}

// Transaction companion extensions for easier creation
extension TransactionCompanionExtensions on TransactionsCompanion {
  /// Create a new transaction companion with required fields
  static TransactionsCompanion create({
    required double amount,
    required String type,
    required int categoryId,
    required int walletId,
    String? notes,
    DateTime? transactionDate,
  }) {
    return TransactionsCompanion.insert(
      amount: amount,
      type: type,
      categoryId: categoryId,
      walletId: walletId,
      notes: notes != null ? Value(notes) : const Value.absent(),
      transactionDate: transactionDate ?? DateTime.now(),
    );
  }

  /// Create an update companion for transaction
  static TransactionsCompanion update({
    double? amount,
    String? type,
    int? categoryId,
    int? walletId,
    String? notes,
    DateTime? transactionDate,
  }) {
    return TransactionsCompanion(
      amount: amount != null ? Value(amount) : const Value.absent(),
      type: type != null ? Value(type) : const Value.absent(),
      categoryId: categoryId != null ? Value(categoryId) : const Value.absent(),
      walletId: walletId != null ? Value(walletId) : const Value.absent(),
      notes: notes != null ? Value(notes) : const Value.absent(),
      transactionDate:
          transactionDate != null
              ? Value(transactionDate)
              : const Value.absent(),
    );
  }
}

// Transaction type enum for better type safety
enum TransactionType {
  income('income'),
  expense('expense');

  const TransactionType(this.value);
  final String value;

  static TransactionType fromString(String value) {
    return TransactionType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => TransactionType.expense,
    );
  }

  String get displayName {
    switch (this) {
      case TransactionType.income:
        return 'Income';
      case TransactionType.expense:
        return 'Expense';
    }
  }
}

// Transaction filter class for filtering operations
class TransactionFilter {
  final int? categoryId;
  final int? walletId;
  final DateTime? startDate;
  final DateTime? endDate;
  final TransactionType? type;
  final String? searchQuery;

  const TransactionFilter({
    this.categoryId,
    this.walletId,
    this.startDate,
    this.endDate,
    this.type,
    this.searchQuery,
  });

  /// Create a copy with updated values
  TransactionFilter copyWith({
    int? categoryId,
    int? walletId,
    DateTime? startDate,
    DateTime? endDate,
    TransactionType? type,
    String? searchQuery,
  }) {
    return TransactionFilter(
      categoryId: categoryId ?? this.categoryId,
      walletId: walletId ?? this.walletId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      type: type ?? this.type,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  /// Check if filter is empty
  bool get isEmpty {
    return categoryId == null &&
        walletId == null &&
        startDate == null &&
        endDate == null &&
        type == null &&
        (searchQuery == null || searchQuery!.isEmpty);
  }

  /// Clear all filters
  static const TransactionFilter empty = TransactionFilter();
}
