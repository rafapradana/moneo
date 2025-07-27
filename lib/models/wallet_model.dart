import 'package:drift/drift.dart';
import 'database.dart';

// Extension methods for Wallet model
extension WalletExtensions on Wallet {
  /// Format balance as USD currency
  String get formattedBalance {
    return '\$${balance.toStringAsFixed(2)}';
  }

  /// Check if wallet has sufficient balance for a transaction
  bool hasSufficientBalance(double amount) {
    return balance >= amount;
  }

  /// Create a copy of wallet with updated balance
  Wallet copyWithBalance(double newBalance) {
    return Wallet(
      id: id,
      name: name,
      balance: newBalance,
      isPinned: isPinned,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Create a copy of wallet with updated pin status
  Wallet copyWithPinStatus(bool pinned) {
    return Wallet(
      id: id,
      name: name,
      balance: balance,
      isPinned: pinned,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

// Wallet companion extensions for easier creation
extension WalletCompanionExtensions on WalletsCompanion {
  /// Create a new wallet companion with required fields
  static WalletsCompanion create({
    required String name,
    double balance = 0.0,
    bool isPinned = false,
  }) {
    return WalletsCompanion.insert(
      name: name,
      balance: Value(balance),
      isPinned: Value(isPinned),
    );
  }

  /// Create an update companion for wallet
  static WalletsCompanion update({
    String? name,
    double? balance,
    bool? isPinned,
  }) {
    return WalletsCompanion(
      name: name != null ? Value(name) : const Value.absent(),
      balance: balance != null ? Value(balance) : const Value.absent(),
      isPinned: isPinned != null ? Value(isPinned) : const Value.absent(),
      updatedAt: Value(DateTime.now()),
    );
  }
}
