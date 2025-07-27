import '../models/database.dart';
import '../models/dao/transaction_dao.dart';

/// Exception thrown when transaction operations fail
class TransactionException implements Exception {
  final String message;
  final String code;

  const TransactionException(this.message, this.code);

  @override
  String toString() => 'TransactionException: $message (Code: $code)';
}

/// Abstract interface for transaction operations
abstract class TransactionService {
  /// Get all transactions from all wallets ordered by date (newest first)
  Future<List<TransactionWithDetails>> getAllTransactions();

  /// Get recent transactions with a specified limit
  Future<List<TransactionWithDetails>> getRecentTransactions(int limit);

  /// Create a new transaction
  Future<Transaction> createTransaction({
    required double amount,
    required String type,
    required int categoryId,
    required int walletId,
    String? notes,
    DateTime? transactionDate,
  });

  /// Update an existing transaction
  Future<void> updateTransaction(
    int id, {
    double? amount,
    String? type,
    int? categoryId,
    int? walletId,
    String? notes,
    DateTime? transactionDate,
  });

  /// Delete a transaction
  Future<void> deleteTransaction(int id);

  /// Get filtered transactions based on criteria
  Future<List<TransactionWithDetails>> getFilteredTransactions({
    int? categoryId,
    int? walletId,
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Get transaction by ID
  Future<TransactionWithDetails?> getTransactionById(int id);

  /// Watch all transactions for reactive UI updates
  Stream<List<TransactionWithDetails>> watchAllTransactions();

  /// Watch recent transactions for reactive UI updates
  Stream<List<TransactionWithDetails>> watchRecentTransactions(int limit);
}
