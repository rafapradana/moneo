import '../models/database.dart';
import '../models/dao/category_dao.dart';
import '../models/dao/recurring_transaction_dao.dart';
import '../models/dao/wallet_dao.dart';
import 'budget_service.dart';

/// Implementation of BudgetService using Drift database
class BudgetServiceImpl implements BudgetService {
  final MoneoDatabase _database;
  late final CategoryDao _categoryDao;
  late final RecurringTransactionDao _recurringTransactionDao;
  late final WalletDao _walletDao;

  BudgetServiceImpl(this._database) {
    _categoryDao = _database.categoryDao;
    _recurringTransactionDao = _database.recurringTransactionDao;
    _walletDao = _database.walletDao;
  }

  // Category management methods
  @override
  Future<List<Category>> getAllCategories() async {
    try {
      return await _categoryDao.getAllCategories();
    } catch (e) {
      throw BudgetException(
        'Failed to retrieve categories: ${e.toString()}',
        'GET_ALL_CATEGORIES_ERROR',
      );
    }
  }

  @override
  Future<List<Category>> getCategoriesByType(String type) async {
    // Validate input
    if (!['income', 'expense', 'savings'].contains(type)) {
      throw BudgetException(
        'Category type must be "income", "expense", or "savings"',
        'INVALID_CATEGORY_TYPE',
      );
    }

    try {
      return await _categoryDao.getCategoriesByType(type);
    } catch (e) {
      throw BudgetException(
        'Failed to retrieve categories by type: ${e.toString()}',
        'GET_CATEGORIES_BY_TYPE_ERROR',
      );
    }
  }

  @override
  Future<Category> createCategory({
    required String name,
    required String type,
    double? monthlyBudget,
    String color = '#2196F3',
  }) async {
    // Validate input
    if (name.trim().isEmpty) {
      throw BudgetException(
        'Category name cannot be empty',
        'INVALID_CATEGORY_NAME',
      );
    }

    if (name.length > 50) {
      throw BudgetException(
        'Category name cannot exceed 50 characters',
        'CATEGORY_NAME_TOO_LONG',
      );
    }

    if (!['income', 'expense', 'savings'].contains(type)) {
      throw BudgetException(
        'Category type must be "income", "expense", or "savings"',
        'INVALID_CATEGORY_TYPE',
      );
    }

    if (monthlyBudget != null && monthlyBudget < 0) {
      throw BudgetException(
        'Monthly budget cannot be negative',
        'INVALID_MONTHLY_BUDGET',
      );
    }

    if (!color.startsWith('#') || color.length != 7) {
      throw BudgetException(
        'Color must be a valid hex color code (e.g., #FF0000)',
        'INVALID_COLOR',
      );
    }

    try {
      // Check if category with same name and type already exists
      final existingCategories = await _categoryDao.getCategoriesByType(type);
      final nameExists = existingCategories.any(
        (category) => category.name.toLowerCase() == name.trim().toLowerCase(),
      );

      if (nameExists) {
        throw BudgetException(
          'A category with this name already exists in this type',
          'DUPLICATE_CATEGORY_NAME',
        );
      }

      return await _categoryDao.createCategory(
        name: name.trim(),
        type: type,
        monthlyBudget: monthlyBudget,
        color: color,
      );
    } catch (e) {
      if (e is BudgetException) rethrow;
      throw BudgetException(
        'Failed to create category: ${e.toString()}',
        'CREATE_CATEGORY_ERROR',
      );
    }
  }

  @override
  Future<void> updateCategory(
    int id, {
    String? name,
    String? type,
    double? monthlyBudget,
    String? color,
  }) async {
    // Validate input
    if (name != null && name.trim().isEmpty) {
      throw BudgetException(
        'Category name cannot be empty',
        'INVALID_CATEGORY_NAME',
      );
    }

    if (name != null && name.length > 50) {
      throw BudgetException(
        'Category name cannot exceed 50 characters',
        'CATEGORY_NAME_TOO_LONG',
      );
    }

    if (type != null && !['income', 'expense', 'savings'].contains(type)) {
      throw BudgetException(
        'Category type must be "income", "expense", or "savings"',
        'INVALID_CATEGORY_TYPE',
      );
    }

    if (monthlyBudget != null && monthlyBudget < 0) {
      throw BudgetException(
        'Monthly budget cannot be negative',
        'INVALID_MONTHLY_BUDGET',
      );
    }

    if (color != null && (!color.startsWith('#') || color.length != 7)) {
      throw BudgetException(
        'Color must be a valid hex color code (e.g., #FF0000)',
        'INVALID_COLOR',
      );
    }

    try {
      // Check if category exists
      final category = await _categoryDao.getCategoryById(id);
      if (category == null) {
        throw BudgetException('Category not found', 'CATEGORY_NOT_FOUND');
      }

      // Check if another category with same name and type already exists
      if (name != null || type != null) {
        final targetType = type ?? category.type;
        final targetName = name?.trim() ?? category.name;

        final existingCategories = await _categoryDao.getCategoriesByType(
          targetType,
        );
        final nameExists = existingCategories.any(
          (c) => c.id != id && c.name.toLowerCase() == targetName.toLowerCase(),
        );

        if (nameExists) {
          throw BudgetException(
            'A category with this name already exists in this type',
            'DUPLICATE_CATEGORY_NAME',
          );
        }
      }

      final success = await _categoryDao.updateCategory(
        id,
        name: name?.trim(),
        type: type,
        monthlyBudget: monthlyBudget,
        color: color,
      );

      if (!success) {
        throw BudgetException(
          'Failed to update category',
          'UPDATE_CATEGORY_ERROR',
        );
      }
    } catch (e) {
      if (e is BudgetException) rethrow;
      throw BudgetException(
        'Failed to update category: ${e.toString()}',
        'UPDATE_CATEGORY_ERROR',
      );
    }
  }

  @override
  Future<void> deleteCategory(int id) async {
    try {
      // Check if category exists
      final category = await _categoryDao.getCategoryById(id);
      if (category == null) {
        throw BudgetException('Category not found', 'CATEGORY_NOT_FOUND');
      }

      final success = await _categoryDao.deleteCategory(id);
      if (!success) {
        throw BudgetException(
          'Cannot delete category with existing transactions',
          'CATEGORY_HAS_TRANSACTIONS',
        );
      }
    } catch (e) {
      if (e is BudgetException) rethrow;
      throw BudgetException(
        'Failed to delete category: ${e.toString()}',
        'DELETE_CATEGORY_ERROR',
      );
    }
  }

  @override
  Future<Category?> getCategoryById(int id) async {
    try {
      return await _categoryDao.getCategoryById(id);
    } catch (e) {
      throw BudgetException(
        'Failed to retrieve category: ${e.toString()}',
        'GET_CATEGORY_BY_ID_ERROR',
      );
    }
  }

  // Budget tracking methods
  @override
  Future<double> getCategorySpending(int categoryId, DateTime month) async {
    try {
      // Check if category exists
      final category = await _categoryDao.getCategoryById(categoryId);
      if (category == null) {
        throw BudgetException('Category not found', 'CATEGORY_NOT_FOUND');
      }

      return await _categoryDao.getCategorySpending(categoryId, month);
    } catch (e) {
      if (e is BudgetException) rethrow;
      throw BudgetException(
        'Failed to retrieve category spending: ${e.toString()}',
        'GET_CATEGORY_SPENDING_ERROR',
      );
    }
  }

  @override
  Future<List<CategoryBudgetProgress>> getBudgetProgress([
    DateTime? month,
  ]) async {
    try {
      return await _categoryDao.getBudgetProgress(month);
    } catch (e) {
      throw BudgetException(
        'Failed to retrieve budget progress: ${e.toString()}',
        'GET_BUDGET_PROGRESS_ERROR',
      );
    }
  }

  @override
  Future<List<Category>> getOverspentCategories([DateTime? month]) async {
    try {
      return await _categoryDao.getOverspentCategories(month);
    } catch (e) {
      throw BudgetException(
        'Failed to retrieve overspent categories: ${e.toString()}',
        'GET_OVERSPENT_CATEGORIES_ERROR',
      );
    }
  }

  @override
  Future<double> getTotalBudget() async {
    try {
      return await _categoryDao.getTotalBudget();
    } catch (e) {
      throw BudgetException(
        'Failed to retrieve total budget: ${e.toString()}',
        'GET_TOTAL_BUDGET_ERROR',
      );
    }
  }

  @override
  Future<double> getTotalMonthlySpending([DateTime? month]) async {
    try {
      return await _categoryDao.getTotalMonthlySpending(month);
    } catch (e) {
      throw BudgetException(
        'Failed to retrieve total monthly spending: ${e.toString()}',
        'GET_TOTAL_MONTHLY_SPENDING_ERROR',
      );
    }
  }

  // Recurring transaction management methods
  @override
  Future<List<RecurringTransactionWithDetails>>
  getRecurringTransactions() async {
    try {
      return await _recurringTransactionDao.getAllRecurringTransactions();
    } catch (e) {
      throw BudgetException(
        'Failed to retrieve recurring transactions: ${e.toString()}',
        'GET_RECURRING_TRANSACTIONS_ERROR',
      );
    }
  }

  @override
  Future<List<RecurringTransactionWithDetails>>
  getActiveRecurringTransactions() async {
    try {
      return await _recurringTransactionDao.getActiveRecurringTransactions();
    } catch (e) {
      throw BudgetException(
        'Failed to retrieve active recurring transactions: ${e.toString()}',
        'GET_ACTIVE_RECURRING_TRANSACTIONS_ERROR',
      );
    }
  }

  @override
  Future<RecurringTransaction> createRecurringTransaction({
    required double amount,
    required String type,
    required int categoryId,
    required int walletId,
    required String frequency,
    required String description,
    DateTime? nextDue,
    bool isActive = true,
  }) async {
    // Validate input
    if (amount <= 0) {
      throw BudgetException('Amount must be greater than 0', 'INVALID_AMOUNT');
    }

    if (!['expense', 'savings'].contains(type)) {
      throw BudgetException(
        'Recurring transaction type must be "expense" or "savings"',
        'INVALID_RECURRING_TYPE',
      );
    }

    if (!['weekly', 'monthly'].contains(frequency)) {
      throw BudgetException(
        'Frequency must be "weekly" or "monthly"',
        'INVALID_FREQUENCY',
      );
    }

    if (description.trim().isEmpty) {
      throw BudgetException(
        'Description cannot be empty',
        'INVALID_DESCRIPTION',
      );
    }

    if (description.length > 200) {
      throw BudgetException(
        'Description cannot exceed 200 characters',
        'DESCRIPTION_TOO_LONG',
      );
    }

    try {
      // Verify wallet exists
      final wallet = await _walletDao.getWalletById(walletId);
      if (wallet == null) {
        throw BudgetException('Wallet not found', 'WALLET_NOT_FOUND');
      }

      // Verify category exists and matches type
      final category = await _categoryDao.getCategoryById(categoryId);
      if (category == null) {
        throw BudgetException('Category not found', 'CATEGORY_NOT_FOUND');
      }

      if (type == 'expense' && category.type != 'expense') {
        throw BudgetException(
          'Expense recurring transactions must use expense categories',
          'INVALID_CATEGORY_TYPE',
        );
      }

      if (type == 'savings' && category.type != 'savings') {
        throw BudgetException(
          'Savings recurring transactions must use savings categories',
          'INVALID_CATEGORY_TYPE',
        );
      }

      return await _recurringTransactionDao.createRecurringTransaction(
        amount: amount,
        type: type,
        categoryId: categoryId,
        walletId: walletId,
        frequency: frequency,
        description: description.trim(),
        nextDue: nextDue,
        isActive: isActive,
      );
    } catch (e) {
      if (e is BudgetException) rethrow;
      throw BudgetException(
        'Failed to create recurring transaction: ${e.toString()}',
        'CREATE_RECURRING_TRANSACTION_ERROR',
      );
    }
  }

  @override
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
  }) async {
    // Validate input
    if (amount != null && amount <= 0) {
      throw BudgetException('Amount must be greater than 0', 'INVALID_AMOUNT');
    }

    if (type != null && !['expense', 'savings'].contains(type)) {
      throw BudgetException(
        'Recurring transaction type must be "expense" or "savings"',
        'INVALID_RECURRING_TYPE',
      );
    }

    if (frequency != null && !['weekly', 'monthly'].contains(frequency)) {
      throw BudgetException(
        'Frequency must be "weekly" or "monthly"',
        'INVALID_FREQUENCY',
      );
    }

    if (description != null && description.trim().isEmpty) {
      throw BudgetException(
        'Description cannot be empty',
        'INVALID_DESCRIPTION',
      );
    }

    if (description != null && description.length > 200) {
      throw BudgetException(
        'Description cannot exceed 200 characters',
        'DESCRIPTION_TOO_LONG',
      );
    }

    try {
      // Check if recurring transaction exists
      final existingTransaction = await _recurringTransactionDao
          .getRecurringTransactionById(id);
      if (existingTransaction == null) {
        throw BudgetException(
          'Recurring transaction not found',
          'RECURRING_TRANSACTION_NOT_FOUND',
        );
      }

      // Verify wallet exists if provided
      if (walletId != null) {
        final wallet = await _walletDao.getWalletById(walletId);
        if (wallet == null) {
          throw BudgetException('Wallet not found', 'WALLET_NOT_FOUND');
        }
      }

      // Verify category exists and matches type if provided
      if (categoryId != null) {
        final category = await _categoryDao.getCategoryById(categoryId);
        if (category == null) {
          throw BudgetException('Category not found', 'CATEGORY_NOT_FOUND');
        }

        final transactionType =
            type ?? existingTransaction.recurringTransaction.type;
        if (transactionType == 'expense' && category.type != 'expense') {
          throw BudgetException(
            'Expense recurring transactions must use expense categories',
            'INVALID_CATEGORY_TYPE',
          );
        }

        if (transactionType == 'savings' && category.type != 'savings') {
          throw BudgetException(
            'Savings recurring transactions must use savings categories',
            'INVALID_CATEGORY_TYPE',
          );
        }
      }

      final success = await _recurringTransactionDao.updateRecurringTransaction(
        id,
        amount: amount,
        type: type,
        categoryId: categoryId,
        walletId: walletId,
        frequency: frequency,
        description: description?.trim(),
        nextDue: nextDue,
        isActive: isActive,
      );

      if (!success) {
        throw BudgetException(
          'Failed to update recurring transaction',
          'UPDATE_RECURRING_TRANSACTION_ERROR',
        );
      }
    } catch (e) {
      if (e is BudgetException) rethrow;
      throw BudgetException(
        'Failed to update recurring transaction: ${e.toString()}',
        'UPDATE_RECURRING_TRANSACTION_ERROR',
      );
    }
  }

  @override
  Future<void> deleteRecurringTransaction(int id) async {
    try {
      // Check if recurring transaction exists
      final recurringTransaction = await _recurringTransactionDao
          .getRecurringTransactionById(id);
      if (recurringTransaction == null) {
        throw BudgetException(
          'Recurring transaction not found',
          'RECURRING_TRANSACTION_NOT_FOUND',
        );
      }

      final success = await _recurringTransactionDao.deleteRecurringTransaction(
        id,
      );
      if (!success) {
        throw BudgetException(
          'Failed to delete recurring transaction',
          'DELETE_RECURRING_TRANSACTION_ERROR',
        );
      }
    } catch (e) {
      if (e is BudgetException) rethrow;
      throw BudgetException(
        'Failed to delete recurring transaction: ${e.toString()}',
        'DELETE_RECURRING_TRANSACTION_ERROR',
      );
    }
  }

  @override
  Future<RecurringTransactionWithDetails?> getRecurringTransactionById(
    int id,
  ) async {
    try {
      return await _recurringTransactionDao.getRecurringTransactionById(id);
    } catch (e) {
      throw BudgetException(
        'Failed to retrieve recurring transaction: ${e.toString()}',
        'GET_RECURRING_TRANSACTION_BY_ID_ERROR',
      );
    }
  }

  // Automated recurring transaction processing
  @override
  Future<int> processRecurringTransactions() async {
    try {
      final dueTransactions =
          await _recurringTransactionDao.getDueRecurringTransactions();
      int processedCount = 0;

      for (final dueTransaction in dueTransactions) {
        final success = await _recurringTransactionDao
            .processRecurringTransaction(
              dueTransaction.recurringTransaction.id,
            );
        if (success) {
          processedCount++;
        }
      }

      return processedCount;
    } catch (e) {
      throw BudgetException(
        'Failed to process recurring transactions: ${e.toString()}',
        'PROCESS_RECURRING_TRANSACTIONS_ERROR',
      );
    }
  }

  @override
  Future<List<RecurringTransactionWithDetails>>
  getDueRecurringTransactions() async {
    try {
      return await _recurringTransactionDao.getDueRecurringTransactions();
    } catch (e) {
      throw BudgetException(
        'Failed to retrieve due recurring transactions: ${e.toString()}',
        'GET_DUE_RECURRING_TRANSACTIONS_ERROR',
      );
    }
  }

  // Watch methods for reactive UI
  @override
  Stream<List<Category>> watchAllCategories() {
    try {
      return _categoryDao.watchAllCategories();
    } catch (e) {
      throw BudgetException(
        'Failed to watch categories: ${e.toString()}',
        'WATCH_CATEGORIES_ERROR',
      );
    }
  }

  @override
  Stream<List<Category>> watchCategoriesByType(String type) {
    // Validate input
    if (!['income', 'expense', 'savings'].contains(type)) {
      throw BudgetException(
        'Category type must be "income", "expense", or "savings"',
        'INVALID_CATEGORY_TYPE',
      );
    }

    try {
      return _categoryDao.watchCategoriesByType(type);
    } catch (e) {
      throw BudgetException(
        'Failed to watch categories by type: ${e.toString()}',
        'WATCH_CATEGORIES_BY_TYPE_ERROR',
      );
    }
  }

  @override
  Stream<List<CategoryBudgetProgress>> watchBudgetProgress() {
    try {
      return _categoryDao.watchBudgetProgress();
    } catch (e) {
      throw BudgetException(
        'Failed to watch budget progress: ${e.toString()}',
        'WATCH_BUDGET_PROGRESS_ERROR',
      );
    }
  }

  @override
  Stream<List<RecurringTransactionWithDetails>> watchRecurringTransactions() {
    try {
      return _recurringTransactionDao.watchAllRecurringTransactions();
    } catch (e) {
      throw BudgetException(
        'Failed to watch recurring transactions: ${e.toString()}',
        'WATCH_RECURRING_TRANSACTIONS_ERROR',
      );
    }
  }

  @override
  Stream<List<RecurringTransactionWithDetails>>
  watchActiveRecurringTransactions() {
    try {
      return _recurringTransactionDao.watchActiveRecurringTransactions();
    } catch (e) {
      throw BudgetException(
        'Failed to watch active recurring transactions: ${e.toString()}',
        'WATCH_ACTIVE_RECURRING_TRANSACTIONS_ERROR',
      );
    }
  }
}
