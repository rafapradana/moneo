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
