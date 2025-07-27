import 'package:drift/drift.dart';
import '../database.dart';
import '../recurring_transaction_model.dart';

part 'recurring_transaction_dao.g.dart';

@DriftAccessor(
  tables: [RecurringTransactions, Categories, Wallets, Transactions],
)
class RecurringTransactionDao extends DatabaseAccessor<MoneoDatabase>
    with _$RecurringTransactionDaoMixin {
  RecurringTransactionDao(super.db);

  // Get all recurring transactions ordered by next due date
  Future<List<RecurringTransactionWithDetails>> getAllRecurringTransactions() {
    final query = select(recurringTransactions).join([
      innerJoin(
        categories,
        categories.id.equalsExp(recurringTransactions.categoryId),
      ),
      innerJoin(wallets, wallets.id.equalsExp(recurringTransactions.walletId)),
    ])..orderBy([OrderingTerm.asc(recurringTransactions.nextDue)]);

    return query
        .map(
          (row) => RecurringTransactionWithDetails(
            recurringTransaction: row.readTable(recurringTransactions),
            category: row.readTable(categories),
            wallet: row.readTable(wallets),
          ),
        )
        .get();
  }

  // Get active recurring transactions
  Future<List<RecurringTransactionWithDetails>>
  getActiveRecurringTransactions() {
    final query =
        select(recurringTransactions).join([
            innerJoin(
              categories,
              categories.id.equalsExp(recurringTransactions.categoryId),
            ),
            innerJoin(
              wallets,
              wallets.id.equalsExp(recurringTransactions.walletId),
            ),
          ])
          ..where(recurringTransactions.isActive.equals(true))
          ..orderBy([OrderingTerm.asc(recurringTransactions.nextDue)]);

    return query
        .map(
          (row) => RecurringTransactionWithDetails(
            recurringTransaction: row.readTable(recurringTransactions),
            category: row.readTable(categories),
            wallet: row.readTable(wallets),
          ),
        )
        .get();
  }

  // Get recurring transaction by ID
  Future<RecurringTransactionWithDetails?> getRecurringTransactionById(
    int id,
  ) async {
    final query = select(recurringTransactions).join([
      innerJoin(
        categories,
        categories.id.equalsExp(recurringTransactions.categoryId),
      ),
      innerJoin(wallets, wallets.id.equalsExp(recurringTransactions.walletId)),
    ])..where(recurringTransactions.id.equals(id));

    final result = await query.getSingleOrNull();
    if (result == null) return null;

    return RecurringTransactionWithDetails(
      recurringTransaction: result.readTable(recurringTransactions),
      category: result.readTable(categories),
      wallet: result.readTable(wallets),
    );
  }

  // Create a new recurring transaction
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
    final recurringTransactionId = await into(recurringTransactions).insert(
      RecurringTransactionsCompanion.insert(
        amount: amount,
        type: type,
        categoryId: categoryId,
        walletId: walletId,
        frequency: frequency,
        description: description,
        nextDue: nextDue ?? _calculateNextDueDate(frequency),
        isActive: Value(isActive),
      ),
    );

    return (await (select(recurringTransactions)
      ..where((rt) => rt.id.equals(recurringTransactionId))).getSingle());
  }

  // Private helper methods
  DateTime _calculateNextDueDate(String frequency) {
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

// Helper class for recurring transaction with category and wallet details
class RecurringTransactionWithDetails {
  final RecurringTransaction recurringTransaction;
  final Category category;
  final Wallet wallet;

  const RecurringTransactionWithDetails({
    required this.recurringTransaction,
    required this.category,
    required this.wallet,
  });

  String get formattedAmount => recurringTransaction.formattedAmount;
  String get formattedAmountWithSign =>
      recurringTransaction.formattedAmountWithSign;
  String get formattedNextDue => recurringTransaction.formattedNextDue;
  String get relativeNextDue => recurringTransaction.relativeNextDue;
  bool get isExpense => recurringTransaction.isExpense;
  bool get isSavings => recurringTransaction.isSavings;
  bool get isDueToday => recurringTransaction.isDueToday;
  bool get isOverdue => recurringTransaction.isOverdue;
}
