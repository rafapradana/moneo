import 'package:drift/drift.dart';
import '../database.dart';
import '../transaction_model.dart';

part 'transaction_dao.g.dart';

@DriftAccessor(tables: [Transactions, Categories, Wallets])
class TransactionDao extends DatabaseAccessor<MoneoDatabase>
    with _$TransactionDaoMixin {
  TransactionDao(super.db);

  // Get all transactions ordered by date (newest first)
  Future<List<TransactionWithDetails>> getAllTransactions() {
    final query = select(transactions).join([
      innerJoin(categories, categories.id.equalsExp(transactions.categoryId)),
      innerJoin(wallets, wallets.id.equalsExp(transactions.walletId)),
    ])..orderBy([OrderingTerm.desc(transactions.transactionDate)]);

    return query
        .map(
          (row) => TransactionWithDetails(
            transaction: row.readTable(transactions),
            category: row.readTable(categories),
            wallet: row.readTable(wallets),
          ),
        )
        .get();
  }

  // Get recent transactions (limited number)
  Future<List<TransactionWithDetails>> getRecentTransactions(int limit) {
    final query =
        select(transactions).join([
            innerJoin(
              categories,
              categories.id.equalsExp(transactions.categoryId),
            ),
            innerJoin(wallets, wallets.id.equalsExp(transactions.walletId)),
          ])
          ..orderBy([OrderingTerm.desc(transactions.transactionDate)])
          ..limit(limit);

    return query
        .map(
          (row) => TransactionWithDetails(
            transaction: row.readTable(transactions),
            category: row.readTable(categories),
            wallet: row.readTable(wallets),
          ),
        )
        .get();
  }

  // Get transaction by ID
  Future<TransactionWithDetails?> getTransactionById(int id) async {
    final query = select(transactions).join([
      innerJoin(categories, categories.id.equalsExp(transactions.categoryId)),
      innerJoin(wallets, wallets.id.equalsExp(transactions.walletId)),
    ])..where(transactions.id.equals(id));

    final result = await query.getSingleOrNull();
    if (result == null) return null;

    return TransactionWithDetails(
      transaction: result.readTable(transactions),
      category: result.readTable(categories),
      wallet: result.readTable(wallets),
    );
  }

  // Get transactions by wallet ID
  Future<List<Transaction>> getTransactionsByWallet(int walletId) {
    return (select(transactions)
          ..where((t) => t.walletId.equals(walletId))
          ..orderBy([(t) => OrderingTerm.desc(t.transactionDate)]))
        .get();
  }

  // Create a new transaction
  Future<Transaction> createTransaction({
    required double amount,
    required String type,
    required int categoryId,
    required int walletId,
    String? notes,
    DateTime? transactionDate,
  }) async {
    final transactionId = await into(transactions).insert(
      TransactionsCompanion.insert(
        amount: amount,
        type: type,
        categoryId: categoryId,
        walletId: walletId,
        notes: notes != null ? Value(notes) : const Value.absent(),
        transactionDate: transactionDate ?? DateTime.now(),
      ),
    );

    // Update wallet balance
    await _updateWalletBalance(walletId, amount, type);

    return (await (select(transactions)
      ..where((t) => t.id.equals(transactionId))).getSingle());
  }

  // Update transaction
  Future<bool> updateTransaction(
    int id, {
    double? amount,
    String? type,
    int? categoryId,
    int? walletId,
    String? notes,
    DateTime? transactionDate,
  }) async {
    // Get original transaction for balance adjustment
    final originalTransaction =
        await (select(transactions)
          ..where((t) => t.id.equals(id))).getSingleOrNull();

    if (originalTransaction == null) return false;

    // Build update companion
    final companion = TransactionsCompanion(
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

    final result = await (update(transactions)
      ..where((t) => t.id.equals(id))).write(companion);

    if (result > 0) {
      // Revert original balance change
      await _revertWalletBalance(
        originalTransaction.walletId,
        originalTransaction.amount,
        originalTransaction.type,
      );

      // Apply new balance change
      await _updateWalletBalance(
        walletId ?? originalTransaction.walletId,
        amount ?? originalTransaction.amount,
        type ?? originalTransaction.type,
      );
    }

    return result > 0;
  }

  // Delete transaction
  Future<bool> deleteTransaction(int id) async {
    // Get transaction for balance adjustment
    final transaction =
        await (select(transactions)
          ..where((t) => t.id.equals(id))).getSingleOrNull();

    if (transaction == null) return false;

    final result =
        await (delete(transactions)..where((t) => t.id.equals(id))).go();

    if (result > 0) {
      // Revert balance change
      await _revertWalletBalance(
        transaction.walletId,
        transaction.amount,
        transaction.type,
      );
    }

    return result > 0;
  }

  // Get filtered transactions
  Future<List<TransactionWithDetails>> getFilteredTransactions({
    int? categoryId,
    int? walletId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final query = select(transactions).join([
      innerJoin(categories, categories.id.equalsExp(transactions.categoryId)),
      innerJoin(wallets, wallets.id.equalsExp(transactions.walletId)),
    ]);

    // Apply filters
    if (categoryId != null) {
      query.where(transactions.categoryId.equals(categoryId));
    }
    if (walletId != null) {
      query.where(transactions.walletId.equals(walletId));
    }
    if (startDate != null) {
      query.where(transactions.transactionDate.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query.where(transactions.transactionDate.isSmallerOrEqualValue(endDate));
    }

    query.orderBy([OrderingTerm.desc(transactions.transactionDate)]);

    return query
        .map(
          (row) => TransactionWithDetails(
            transaction: row.readTable(transactions),
            category: row.readTable(categories),
            wallet: row.readTable(wallets),
          ),
        )
        .get();
  }

  // Watch all transactions for reactive UI
  Stream<List<TransactionWithDetails>> watchAllTransactions() {
    final query = select(transactions).join([
      innerJoin(categories, categories.id.equalsExp(transactions.categoryId)),
      innerJoin(wallets, wallets.id.equalsExp(transactions.walletId)),
    ])..orderBy([OrderingTerm.desc(transactions.transactionDate)]);

    return query
        .map(
          (row) => TransactionWithDetails(
            transaction: row.readTable(transactions),
            category: row.readTable(categories),
            wallet: row.readTable(wallets),
          ),
        )
        .watch();
  }

  // Watch recent transactions
  Stream<List<TransactionWithDetails>> watchRecentTransactions(int limit) {
    final query =
        select(transactions).join([
            innerJoin(
              categories,
              categories.id.equalsExp(transactions.categoryId),
            ),
            innerJoin(wallets, wallets.id.equalsExp(transactions.walletId)),
          ])
          ..orderBy([OrderingTerm.desc(transactions.transactionDate)])
          ..limit(limit);

    return query
        .map(
          (row) => TransactionWithDetails(
            transaction: row.readTable(transactions),
            category: row.readTable(categories),
            wallet: row.readTable(wallets),
          ),
        )
        .watch();
  }

  // Private helper methods
  Future<void> _updateWalletBalance(
    int walletId,
    double amount,
    String type,
  ) async {
    final balanceChange = type == 'income' ? amount : -amount;
    await customUpdate(
      'UPDATE wallets SET balance = balance + ?, updated_at = ? WHERE id = ?',
      variables: [
        Variable.withReal(balanceChange),
        Variable.withDateTime(DateTime.now()),
        Variable.withInt(walletId),
      ],
    );
  }

  Future<void> _revertWalletBalance(
    int walletId,
    double amount,
    String type,
  ) async {
    final balanceChange = type == 'income' ? -amount : amount;
    await customUpdate(
      'UPDATE wallets SET balance = balance + ?, updated_at = ? WHERE id = ?',
      variables: [
        Variable.withReal(balanceChange),
        Variable.withDateTime(DateTime.now()),
        Variable.withInt(walletId),
      ],
    );
  }
}

// Helper class for transaction with category and wallet details
class TransactionWithDetails {
  final Transaction transaction;
  final Category category;
  final Wallet wallet;

  const TransactionWithDetails({
    required this.transaction,
    required this.category,
    required this.wallet,
  });

  String get formattedAmount => transaction.formattedAmount;
  String get formattedAmountWithSign => transaction.formattedAmountWithSign;
  String get formattedDate => transaction.formattedDate;
  String get formattedDateTime => transaction.formattedDateTime;
  String get relativeTime => transaction.relativeTime;
  bool get isIncome => transaction.isIncome;
  bool get isExpense => transaction.isExpense;
}
