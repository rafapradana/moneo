import '../models/database.dart';
import '../models/dao/transaction_dao.dart';
import '../models/dao/wallet_dao.dart';
import '../models/dao/category_dao.dart';
import 'transaction_service.dart';

/// Implementation of TransactionService using Drift database
class TransactionServiceImpl implements TransactionService {
  final MoneoDatabase _database;
  late final TransactionDao _transactionDao;
  late final WalletDao _walletDao;
  late final CategoryDao _categoryDao;

  TransactionServiceImpl(this._database) {
    _transactionDao = _database.transactionDao;
    _walletDao = _database.walletDao;
    _categoryDao = _database.categoryDao;
  }

  @override
  Future<List<TransactionWithDetails>> getAllTransactions() async {
    try {
      return await _transactionDao.getAllTransactions();
    } catch (e) {
      throw TransactionException(
        'Failed to retrieve transactions: ${e.toString()}',
        'GET_ALL_TRANSACTIONS_ERROR',
      );
    }
  }

  @override
  Future<List<TransactionWithDetails>> getRecentTransactions(int limit) async {
    // Validate input
    if (limit <= 0) {
      throw TransactionException(
        'Limit must be greater than 0',
        'INVALID_LIMIT',
      );
    }

    try {
      return await _transactionDao.getRecentTransactions(limit);
    } catch (e) {
      throw TransactionException(
        'Failed to retrieve recent transactions: ${e.toString()}',
        'GET_RECENT_TRANSACTIONS_ERROR',
      );
    }
  }

  @override
  Future<Transaction> createTransaction({
    required double amount,
    required String type,
    required int categoryId,
    required int walletId,
    String? notes,
    DateTime? transactionDate,
  }) async {
    // Validate input
    if (amount <= 0) {
      throw TransactionException(
        'Amount must be greater than 0',
        'INVALID_AMOUNT',
      );
    }

    if (!['income', 'expense'].contains(type)) {
      throw TransactionException(
        'Transaction type must be either "income" or "expense"',
        'INVALID_TRANSACTION_TYPE',
      );
    }

    if (notes != null && notes.length > 500) {
      throw TransactionException(
        'Notes cannot exceed 500 characters',
        'NOTES_TOO_LONG',
      );
    }

    try {
      // Verify wallet exists
      final wallet = await _walletDao.getWalletById(walletId);
      if (wallet == null) {
        throw TransactionException('Wallet not found', 'WALLET_NOT_FOUND');
      }

      // Verify category exists
      final category = await _categoryDao.getCategoryById(categoryId);
      if (category == null) {
        throw TransactionException('Category not found', 'CATEGORY_NOT_FOUND');
      }

      // For expenses, check if wallet has sufficient balance
      if (type == 'expense' && wallet.balance < amount) {
        throw TransactionException(
          'Insufficient wallet balance',
          'INSUFFICIENT_BALANCE',
        );
      }

      // Validate category type matches transaction type
      if (type == 'income' && category.type != 'income') {
        throw TransactionException(
          'Income transactions must use income categories',
          'INVALID_CATEGORY_TYPE',
        );
      }

      if (type == 'expense' && category.type != 'expense') {
        throw TransactionException(
          'Expense transactions must use expense categories',
          'INVALID_CATEGORY_TYPE',
        );
      }

      return await _transactionDao.createTransaction(
        amount: amount,
        type: type,
        categoryId: categoryId,
        walletId: walletId,
        notes: notes?.trim(),
        transactionDate: transactionDate,
      );
    } catch (e) {
      if (e is TransactionException) rethrow;
      throw TransactionException(
        'Failed to create transaction: ${e.toString()}',
        'CREATE_TRANSACTION_ERROR',
      );
    }
  }

  @override
  Future<void> updateTransaction(
    int id, {
    double? amount,
    String? type,
    int? categoryId,
    int? walletId,
    String? notes,
    DateTime? transactionDate,
  }) async {
    // Validate input
    if (amount != null && amount <= 0) {
      throw TransactionException(
        'Amount must be greater than 0',
        'INVALID_AMOUNT',
      );
    }

    if (type != null && !['income', 'expense'].contains(type)) {
      throw TransactionException(
        'Transaction type must be either "income" or "expense"',
        'INVALID_TRANSACTION_TYPE',
      );
    }

    if (notes != null && notes.length > 500) {
      throw TransactionException(
        'Notes cannot exceed 500 characters',
        'NOTES_TOO_LONG',
      );
    }

    try {
      // Check if transaction exists
      final existingTransaction = await _transactionDao.getTransactionById(id);
      if (existingTransaction == null) {
        throw TransactionException(
          'Transaction not found',
          'TRANSACTION_NOT_FOUND',
        );
      }

      // Verify wallet exists if provided
      if (walletId != null) {
        final wallet = await _walletDao.getWalletById(walletId);
        if (wallet == null) {
          throw TransactionException('Wallet not found', 'WALLET_NOT_FOUND');
        }
      }

      // Verify category exists if provided
      if (categoryId != null) {
        final category = await _categoryDao.getCategoryById(categoryId);
        if (category == null) {
          throw TransactionException(
            'Category not found',
            'CATEGORY_NOT_FOUND',
          );
        }

        // Validate category type matches transaction type
        final transactionType = type ?? existingTransaction.transaction.type;
        if (transactionType == 'income' && category.type != 'income') {
          throw TransactionException(
            'Income transactions must use income categories',
            'INVALID_CATEGORY_TYPE',
          );
        }

        if (transactionType == 'expense' && category.type != 'expense') {
          throw TransactionException(
            'Expense transactions must use expense categories',
            'INVALID_CATEGORY_TYPE',
          );
        }
      }

      final success = await _transactionDao.updateTransaction(
        id,
        amount: amount,
        type: type,
        categoryId: categoryId,
        walletId: walletId,
        notes: notes?.trim(),
        transactionDate: transactionDate,
      );

      if (!success) {
        throw TransactionException(
          'Failed to update transaction',
          'UPDATE_TRANSACTION_ERROR',
        );
      }
    } catch (e) {
      if (e is TransactionException) rethrow;
      throw TransactionException(
        'Failed to update transaction: ${e.toString()}',
        'UPDATE_TRANSACTION_ERROR',
      );
    }
  }

  @override
  Future<void> deleteTransaction(int id) async {
    try {
      // Check if transaction exists
      final transaction = await _transactionDao.getTransactionById(id);
      if (transaction == null) {
        throw TransactionException(
          'Transaction not found',
          'TRANSACTION_NOT_FOUND',
        );
      }

      final success = await _transactionDao.deleteTransaction(id);
      if (!success) {
        throw TransactionException(
          'Failed to delete transaction',
          'DELETE_TRANSACTION_ERROR',
        );
      }
    } catch (e) {
      if (e is TransactionException) rethrow;
      throw TransactionException(
        'Failed to delete transaction: ${e.toString()}',
        'DELETE_TRANSACTION_ERROR',
      );
    }
  }

  @override
  Future<List<TransactionWithDetails>> getFilteredTransactions({
    int? categoryId,
    int? walletId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // Validate date range
    if (startDate != null && endDate != null && startDate.isAfter(endDate)) {
      throw TransactionException(
        'Start date cannot be after end date',
        'INVALID_DATE_RANGE',
      );
    }

    try {
      // Verify wallet exists if provided
      if (walletId != null) {
        final wallet = await _walletDao.getWalletById(walletId);
        if (wallet == null) {
          throw TransactionException('Wallet not found', 'WALLET_NOT_FOUND');
        }
      }

      // Verify category exists if provided
      if (categoryId != null) {
        final category = await _categoryDao.getCategoryById(categoryId);
        if (category == null) {
          throw TransactionException(
            'Category not found',
            'CATEGORY_NOT_FOUND',
          );
        }
      }

      return await _transactionDao.getFilteredTransactions(
        categoryId: categoryId,
        walletId: walletId,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      if (e is TransactionException) rethrow;
      throw TransactionException(
        'Failed to retrieve filtered transactions: ${e.toString()}',
        'GET_FILTERED_TRANSACTIONS_ERROR',
      );
    }
  }

  @override
  Future<TransactionWithDetails?> getTransactionById(int id) async {
    try {
      return await _transactionDao.getTransactionById(id);
    } catch (e) {
      throw TransactionException(
        'Failed to retrieve transaction: ${e.toString()}',
        'GET_TRANSACTION_BY_ID_ERROR',
      );
    }
  }

  @override
  Stream<List<TransactionWithDetails>> watchAllTransactions() {
    try {
      return _transactionDao.watchAllTransactions();
    } catch (e) {
      throw TransactionException(
        'Failed to watch transactions: ${e.toString()}',
        'WATCH_TRANSACTIONS_ERROR',
      );
    }
  }

  @override
  Stream<List<TransactionWithDetails>> watchRecentTransactions(int limit) {
    // Validate input
    if (limit <= 0) {
      throw TransactionException(
        'Limit must be greater than 0',
        'INVALID_LIMIT',
      );
    }

    try {
      return _transactionDao.watchRecentTransactions(limit);
    } catch (e) {
      throw TransactionException(
        'Failed to watch recent transactions: ${e.toString()}',
        'WATCH_RECENT_TRANSACTIONS_ERROR',
      );
    }
  }
}
