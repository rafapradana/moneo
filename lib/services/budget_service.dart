import '../models/database.dart';
import '../models/dao/category_dao.dart';
import '../models/dao/recurring_transaction_dao.dart';

/// Exception thrown when budget operations fail
class BudgetException implements Exception {
  final String message;
  final String code;

  const BudgetException(this.message, this.code);

  @override
  String toString() => 'BudgetException: $message (Code: $code)';
}

/// Abstract interface for budget and category operations
abstract class BudgetService {
  // Category management methods
  Future<List<Category>> getAllCategories();
  Future<List<Category>> getCategoriesByType(String type);
  Future<Category> createCategory({
    required String name,
    required String type,
    double? monthlyBudget,
    String color = '#2196F3',
  });
  Future<void> updateCategory(
    int id, {
    String? name,
    String? type,
    double? monthlyBudget,
    String? color,
  });
  Future<void> deleteCategory(int id);
  Future<Category?> getCategoryById(int id);

  // Budget tracking methods
  Future<double> getCategorySpending(int categoryId, DateTime month);
  Future<List<CategoryBudgetProgress>> getBudgetProgress([DateTime? month]);
  Future<List<Category>> getOverspentCategories([DateTime? month]);
  Future<double> getTotalBudget();
  Future<double> getTotalMonthlySpending([DateTime? month]);

  // Recurring transaction management methods
  Future<List<RecurringTransactionWithDetails>> getRecurringTransactions();
  Future<List<RecurringTransactionWithDetails>>
  getActiveRecurringTransactions();
  Future<RecurringTransaction> createRecurringTransaction({
    required double amount,
    required String type,
    required int categoryId,
    required int walletId,
    required String frequency,
    required String description,
    DateTime? nextDue,
    bool isActive = true,
  });
  Future<void> updateRecurringTransaction(
    int id, {
    double? amount,
    String? type,
    int? categoryId,
    int? walletId,
    String? frequency,
    String? description,
    DateTime? nextDue,
    bool? isActive,
  });
  Future<void> deleteRecurringTransaction(int id);
  Future<RecurringTransactionWithDetails?> getRecurringTransactionById(int id);

  // Automated recurring transaction processing
  Future<int> processRecurringTransactions();
  Future<List<RecurringTransactionWithDetails>> getDueRecurringTransactions();

  // Watch methods for reactive UI
  Stream<List<Category>> watchAllCategories();
  Stream<List<Category>> watchCategoriesByType(String type);
  Stream<List<CategoryBudgetProgress>> watchBudgetProgress();
  Stream<List<RecurringTransactionWithDetails>> watchRecurringTransactions();
  Stream<List<RecurringTransactionWithDetails>>
  watchActiveRecurringTransactions();
}
