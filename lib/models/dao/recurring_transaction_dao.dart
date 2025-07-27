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

  // Update recurring transaction
  Future<bool> updateRecurringTransaction(
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
    final companion = RecurringTransactionsCompanion(
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

    final result = await (update(recurringTransactions)
      ..where((rt) => rt.id.equals(id))).write(companion);
    return result > 0;
  }

  // Delete recurring transaction
  Future<bool> deleteRecurringTransaction(int id) async {
    final result =
        await (delete(recurringTransactions)
          ..where((rt) => rt.id.equals(id))).go();
    return result > 0;
  }

  // Get due recurring transactions
  Future<List<RecurringTransactionWithDetails>> getDueRecurringTransactions() {
    final now = DateTime.now();
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
          ..where(recurringTransactions.nextDue.isSmallerOrEqualValue(now))
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

  // Process a recurring transaction (create actual transaction and update next due)
  Future<bool> processRecurringTransaction(int id) async {
    final recurringTransaction = await getRecurringTransactionById(id);
    if (recurringTransaction == null ||
        !recurringTransaction.recurringTransaction.isActive) {
      return false;
    }

    final rt = recurringTransaction.recurringTransaction;

    // Create the actual transaction
    final transactionId = await into(transactions).insert(
      TransactionsCompanion.insert(
        amount: rt.amount,
        type: rt.type,
        categoryId: rt.categoryId,
        walletId: rt.walletId,
        notes: Value('Recurring: ${rt.description}'),
        transactionDate: DateTime.now(),
      ),
    );

    if (transactionId > 0) {
      // Update wallet balance
      await _updateWalletBalance(rt.walletId, rt.amount, rt.type);

      // Update next due date
      final nextDue = _calculateNextDueDate(rt.frequency, rt.nextDue);
      await updateRecurringTransaction(id, nextDue: nextDue);

      return true;
    }

    return false;
  }

  // Watch all recurring transactions
  Stream<List<RecurringTransactionWithDetails>>
  watchAllRecurringTransactions() {
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
        .watch();
  }

  // Watch active recurring transactions
  Stream<List<RecurringTransactionWithDetails>>
  watchActiveRecurringTransactions() {
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
        .watch();
  }

  // Private helper methods
  DateTime _calculateNextDueDate(String frequency, [DateTime? currentDue]) {
    final baseDate = currentDue ?? DateTime.now();
    switch (frequency) {
      case 'weekly':
        return baseDate.add(const Duration(days: 7));
      case 'monthly':
        return DateTime(
          baseDate.year,
          baseDate.month + 1,
          baseDate.day,
          baseDate.hour,
          baseDate.minute,
        );
      default:
        return baseDate;
    }
  }

  Future<void> _updateWalletBalance(
    int walletId,
    double amount,
    String type,
  ) async {
    final balanceChange = type == 'expense' ? -amount : amount;
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
