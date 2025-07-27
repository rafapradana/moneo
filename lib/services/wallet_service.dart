import '../models/database.dart';

/// Exception thrown when wallet operations fail
class WalletException implements Exception {
  final String message;
  final String code;

  const WalletException(this.message, this.code);

  @override
  String toString() => 'WalletException: $message (Code: $code)';
}

/// Abstract interface for wallet operations
abstract class WalletService {
  /// Get all wallets ordered by creation date
  Future<List<Wallet>> getAllWallets();

  /// Get pinned wallets (maximum 4 for dashboard)
  Future<List<Wallet>> getPinnedWallets();

  /// Create a new wallet with the given name and initial balance
  Future<Wallet> createWallet(String name, {double initialBalance = 0.0});

  /// Update wallet name
  Future<void> updateWallet(int id, String name);

  /// Delete wallet (only if no transactions exist)
  Future<void> deleteWallet(int id);

  /// Toggle wallet pin status (maximum 4 pinned wallets allowed)
  Future<void> togglePinWallet(int id);

  /// Calculate total balance across all wallets
  Future<double> getTotalBalance();

  /// Get wallet transactions for a specific wallet
  Future<List<Transaction>> getWalletTransactions(int walletId);

  /// Get wallet by ID
  Future<Wallet?> getWalletById(int id);

  /// Sync wallet balance with actual transactions
  Future<void> syncWalletBalance(int walletId);

  /// Watch all wallets for reactive UI updates
  Stream<List<Wallet>> watchAllWallets();

  /// Watch pinned wallets for dashboard updates
  Stream<List<Wallet>> watchPinnedWallets();

  /// Watch total balance for reactive updates
  Stream<double> watchTotalBalance();
}
