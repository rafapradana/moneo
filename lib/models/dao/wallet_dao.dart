import 'package:drift/drift.dart';
import '../database.dart';

part 'wallet_dao.g.dart';

@DriftAccessor(tables: [Wallets, Transactions])
class WalletDao extends DatabaseAccessor<MoneoDatabase> with _$WalletDaoMixin {
  WalletDao(super.db);

  // Get all wallets ordered by creation date
  Future<List<Wallet>> getAllWallets() {
    return (select(wallets)
      ..orderBy([(w) => OrderingTerm.desc(w.createdAt)])).get();
  }

  // Get pinned wallets (maximum 4 for dashboard)
  Future<List<Wallet>> getPinnedWallets() {
    return (select(wallets)
          ..where((w) => w.isPinned.equals(true))
          ..orderBy([(w) => OrderingTerm.desc(w.createdAt)])
          ..limit(4))
        .get();
  }

  // Get wallet by ID
  Future<Wallet?> getWalletById(int id) {
    return (select(wallets)..where((w) => w.id.equals(id))).getSingleOrNull();
  }

  // Create a new wallet
  Future<Wallet> createWallet(
    String name, {
    double initialBalance = 0.0,
    bool isPinned = false,
  }) async {
    final walletId = await into(wallets).insert(
      WalletsCompanion.insert(
        name: name,
        balance: Value(initialBalance),
        isPinned: Value(isPinned),
      ),
    );

    return (await getWalletById(walletId))!;
  }

  // Update wallet name
  Future<bool> updateWalletName(int id, String name) async {
    final result = await (update(wallets)..where((w) => w.id.equals(id))).write(
      WalletsCompanion(name: Value(name), updatedAt: Value(DateTime.now())),
    );
    return result > 0;
  }

  // Update wallet balance
  Future<bool> updateWalletBalance(int id, double balance) async {
    final result = await (update(wallets)..where((w) => w.id.equals(id))).write(
      WalletsCompanion(
        balance: Value(balance),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return result > 0;
  }

  // Toggle wallet pin status
  Future<bool> togglePinWallet(int id) async {
    final wallet = await getWalletById(id);
    if (wallet == null) return false;

    // If pinning, check if we already have 4 pinned wallets
    if (!wallet.isPinned) {
      final pinnedCount =
          await (selectOnly(wallets)
                ..addColumns([wallets.id.count()])
                ..where(wallets.isPinned.equals(true)))
              .getSingle();

      if ((pinnedCount.read(wallets.id.count()) ?? 0) >= 4) {
        return false; // Cannot pin more than 4 wallets
      }
    }

    final result = await (update(wallets)..where((w) => w.id.equals(id))).write(
      WalletsCompanion(
        isPinned: Value(!wallet.isPinned),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return result > 0;
  }

  // Delete wallet (only if no transactions exist)
  Future<bool> deleteWallet(int id) async {
    // Check if wallet has transactions
    final transactionCount =
        await (selectOnly(transactions)
              ..addColumns([transactions.id.count()])
              ..where(transactions.walletId.equals(id)))
            .getSingle();

    if ((transactionCount.read(transactions.id.count()) ?? 0) > 0) {
      return false; // Cannot delete wallet with transactions
    }

    final result = await (delete(wallets)..where((w) => w.id.equals(id))).go();
    return result > 0;
  }

  // Calculate total balance across all wallets
  Future<double> getTotalBalance() async {
    final result =
        await (selectOnly(wallets)
          ..addColumns([wallets.balance.sum()])).getSingle();

    return result.read(wallets.balance.sum()) ?? 0.0;
  }

  // Calculate wallet balance from transactions (for verification)
  Future<double> calculateWalletBalanceFromTransactions(int walletId) async {
    final result =
        await customSelect(
          '''
      SELECT 
        COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE -amount END), 0) as calculated_balance
      FROM transactions 
      WHERE wallet_id = ?
      ''',
          variables: [Variable.withInt(walletId)],
        ).getSingle();

    return result.read<double>('calculated_balance') ?? 0.0;
  }

  // Sync wallet balance with transactions
  Future<bool> syncWalletBalance(int walletId) async {
    final calculatedBalance = await calculateWalletBalanceFromTransactions(
      walletId,
    );
    return await updateWalletBalance(walletId, calculatedBalance);
  }

  // Get wallet with transaction count
  Future<List<WalletWithTransactionCount>>
  getWalletsWithTransactionCount() async {
    final query = select(wallets).join([
      leftOuterJoin(transactions, transactions.walletId.equalsExp(wallets.id)),
    ]);

    final results = await query.get();
    final Map<int, WalletWithTransactionCount> walletMap = {};

    for (final row in results) {
      final wallet = row.readTable(wallets);
      final transaction = row.readTableOrNull(transactions);

      if (!walletMap.containsKey(wallet.id)) {
        walletMap[wallet.id] = WalletWithTransactionCount(
          wallet: wallet,
          transactionCount: 0,
        );
      }

      if (transaction != null) {
        walletMap[wallet.id] = walletMap[wallet.id]!.copyWith(
          transactionCount: walletMap[wallet.id]!.transactionCount + 1,
        );
      }
    }

    return walletMap.values.toList()
      ..sort((a, b) => b.wallet.createdAt.compareTo(a.wallet.createdAt));
  }

  // Watch all wallets (for reactive UI)
  Stream<List<Wallet>> watchAllWallets() {
    return (select(wallets)
      ..orderBy([(w) => OrderingTerm.desc(w.createdAt)])).watch();
  }

  // Watch pinned wallets (for dashboard)
  Stream<List<Wallet>> watchPinnedWallets() {
    return (select(wallets)
          ..where((w) => w.isPinned.equals(true))
          ..orderBy([(w) => OrderingTerm.desc(w.createdAt)])
          ..limit(4))
        .watch();
  }

  // Watch total balance
  Stream<double> watchTotalBalance() {
    return (selectOnly(wallets)..addColumns([
      wallets.balance.sum(),
    ])).map((row) => row.read(wallets.balance.sum()) ?? 0.0).watchSingle();
  }
}

// Helper class for wallet with transaction count
class WalletWithTransactionCount {
  final Wallet wallet;
  final int transactionCount;

  const WalletWithTransactionCount({
    required this.wallet,
    required this.transactionCount,
  });

  WalletWithTransactionCount copyWith({Wallet? wallet, int? transactionCount}) {
    return WalletWithTransactionCount(
      wallet: wallet ?? this.wallet,
      transactionCount: transactionCount ?? this.transactionCount,
    );
  }
}
