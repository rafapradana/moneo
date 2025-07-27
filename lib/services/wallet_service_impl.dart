import '../models/database.dart';
import '../models/dao/wallet_dao.dart';
import '../models/dao/transaction_dao.dart';
import 'wallet_service.dart';

/// Implementation of WalletService using Drift database
class WalletServiceImpl implements WalletService {
  final MoneoDatabase _database;
  late final WalletDao _walletDao;
  late final TransactionDao _transactionDao;

  WalletServiceImpl(this._database) {
    _walletDao = _database.walletDao;
    _transactionDao = _database.transactionDao;
  }

  @override
  Future<List<Wallet>> getAllWallets() async {
    try {
      return await _walletDao.getAllWallets();
    } catch (e) {
      throw WalletException(
        'Failed to retrieve wallets: ${e.toString()}',
        'GET_ALL_WALLETS_ERROR',
      );
    }
  }

  @override
  Future<List<Wallet>> getPinnedWallets() async {
    try {
      return await _walletDao.getPinnedWallets();
    } catch (e) {
      throw WalletException(
        'Failed to retrieve pinned wallets: ${e.toString()}',
        'GET_PINNED_WALLETS_ERROR',
      );
    }
  }

  @override
  Future<Wallet> createWallet(
    String name, {
    double initialBalance = 0.0,
  }) async {
    // Validate input
    if (name.trim().isEmpty) {
      throw WalletException(
        'Wallet name cannot be empty',
        'INVALID_WALLET_NAME',
      );
    }

    if (name.length > 100) {
      throw WalletException(
        'Wallet name cannot exceed 100 characters',
        'WALLET_NAME_TOO_LONG',
      );
    }

    if (initialBalance < 0) {
      throw WalletException(
        'Initial balance cannot be negative',
        'INVALID_INITIAL_BALANCE',
      );
    }

    try {
      // Check if wallet with same name already exists
      final existingWallets = await _walletDao.getAllWallets();
      final nameExists = existingWallets.any(
        (wallet) => wallet.name.toLowerCase() == name.trim().toLowerCase(),
      );

      if (nameExists) {
        throw WalletException(
          'A wallet with this name already exists',
          'DUPLICATE_WALLET_NAME',
        );
      }

      return await _walletDao.createWallet(
        name.trim(),
        initialBalance: initialBalance,
      );
    } catch (e) {
      if (e is WalletException) rethrow;
      throw WalletException(
        'Failed to create wallet: ${e.toString()}',
        'CREATE_WALLET_ERROR',
      );
    }
  }

  @override
  Future<void> updateWallet(int id, String name) async {
    // Validate input
    if (name.trim().isEmpty) {
      throw WalletException(
        'Wallet name cannot be empty',
        'INVALID_WALLET_NAME',
      );
    }

    if (name.length > 100) {
      throw WalletException(
        'Wallet name cannot exceed 100 characters',
        'WALLET_NAME_TOO_LONG',
      );
    }

    try {
      // Check if wallet exists
      final wallet = await _walletDao.getWalletById(id);
      if (wallet == null) {
        throw WalletException('Wallet not found', 'WALLET_NOT_FOUND');
      }

      // Check if another wallet with same name already exists
      final existingWallets = await _walletDao.getAllWallets();
      final nameExists = existingWallets.any(
        (w) => w.id != id && w.name.toLowerCase() == name.trim().toLowerCase(),
      );

      if (nameExists) {
        throw WalletException(
          'A wallet with this name already exists',
          'DUPLICATE_WALLET_NAME',
        );
      }

      final success = await _walletDao.updateWalletName(id, name.trim());
      if (!success) {
        throw WalletException('Failed to update wallet', 'UPDATE_WALLET_ERROR');
      }
    } catch (e) {
      if (e is WalletException) rethrow;
      throw WalletException(
        'Failed to update wallet: ${e.toString()}',
        'UPDATE_WALLET_ERROR',
      );
    }
  }

  @override
  Future<void> deleteWallet(int id) async {
    try {
      // Check if wallet exists
      final wallet = await _walletDao.getWalletById(id);
      if (wallet == null) {
        throw WalletException('Wallet not found', 'WALLET_NOT_FOUND');
      }

      final success = await _walletDao.deleteWallet(id);
      if (!success) {
        throw WalletException(
          'Cannot delete wallet with existing transactions',
          'WALLET_HAS_TRANSACTIONS',
        );
      }
    } catch (e) {
      if (e is WalletException) rethrow;
      throw WalletException(
        'Failed to delete wallet: ${e.toString()}',
        'DELETE_WALLET_ERROR',
      );
    }
  }

  @override
  Future<void> togglePinWallet(int id) async {
    try {
      // Check if wallet exists
      final wallet = await _walletDao.getWalletById(id);
      if (wallet == null) {
        throw WalletException('Wallet not found', 'WALLET_NOT_FOUND');
      }

      final success = await _walletDao.togglePinWallet(id);
      if (!success) {
        throw WalletException(
          'Cannot pin more than 4 wallets',
          'MAX_PINNED_WALLETS_EXCEEDED',
        );
      }
    } catch (e) {
      if (e is WalletException) rethrow;
      throw WalletException(
        'Failed to toggle wallet pin status: ${e.toString()}',
        'TOGGLE_PIN_ERROR',
      );
    }
  }

  @override
  Future<double> getTotalBalance() async {
    try {
      return await _walletDao.getTotalBalance();
    } catch (e) {
      throw WalletException(
        'Failed to calculate total balance: ${e.toString()}',
        'GET_TOTAL_BALANCE_ERROR',
      );
    }
  }

  @override
  Future<List<Transaction>> getWalletTransactions(int walletId) async {
    try {
      // Check if wallet exists
      final wallet = await _walletDao.getWalletById(walletId);
      if (wallet == null) {
        throw WalletException('Wallet not found', 'WALLET_NOT_FOUND');
      }

      return await _transactionDao.getTransactionsByWallet(walletId);
    } catch (e) {
      if (e is WalletException) rethrow;
      throw WalletException(
        'Failed to retrieve wallet transactions: ${e.toString()}',
        'GET_WALLET_TRANSACTIONS_ERROR',
      );
    }
  }

  @override
  Future<Wallet?> getWalletById(int id) async {
    try {
      return await _walletDao.getWalletById(id);
    } catch (e) {
      throw WalletException(
        'Failed to retrieve wallet: ${e.toString()}',
        'GET_WALLET_BY_ID_ERROR',
      );
    }
  }

  @override
  Future<void> syncWalletBalance(int walletId) async {
    try {
      // Check if wallet exists
      final wallet = await _walletDao.getWalletById(walletId);
      if (wallet == null) {
        throw WalletException('Wallet not found', 'WALLET_NOT_FOUND');
      }

      final success = await _walletDao.syncWalletBalance(walletId);
      if (!success) {
        throw WalletException(
          'Failed to sync wallet balance',
          'SYNC_BALANCE_ERROR',
        );
      }
    } catch (e) {
      if (e is WalletException) rethrow;
      throw WalletException(
        'Failed to sync wallet balance: ${e.toString()}',
        'SYNC_BALANCE_ERROR',
      );
    }
  }

  @override
  Stream<List<Wallet>> watchAllWallets() {
    try {
      return _walletDao.watchAllWallets();
    } catch (e) {
      throw WalletException(
        'Failed to watch wallets: ${e.toString()}',
        'WATCH_WALLETS_ERROR',
      );
    }
  }

  @override
  Stream<List<Wallet>> watchPinnedWallets() {
    try {
      return _walletDao.watchPinnedWallets();
    } catch (e) {
      throw WalletException(
        'Failed to watch pinned wallets: ${e.toString()}',
        'WATCH_PINNED_WALLETS_ERROR',
      );
    }
  }

  @override
  Stream<double> watchTotalBalance() {
    try {
      return _walletDao.watchTotalBalance();
    } catch (e) {
      throw WalletException(
        'Failed to watch total balance: ${e.toString()}',
        'WATCH_TOTAL_BALANCE_ERROR',
      );
    }
  }
}
