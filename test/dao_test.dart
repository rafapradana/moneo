import 'package:flutter_test/flutter_test.dart';
import 'package:moneo/models/models.dart';

void main() {
  group('DAO Tests', () {
    late MoneoDatabase database;

    setUp(() {
      // Use in-memory database for testing
      database = MoneoDatabase();
    });

    tearDown(() async {
      await database.close();
    });

    test('should create and retrieve wallet', () async {
      // Create a wallet
      final wallet = await database.walletDao.createWallet(
        'Test Wallet',
        initialBalance: 100.0,
      );

      expect(wallet.name, 'Test Wallet');
      expect(wallet.balance, 100.0);
      expect(wallet.isPinned, false);

      // Retrieve the wallet
      final retrievedWallet = await database.walletDao.getWalletById(wallet.id);
      expect(retrievedWallet, isNotNull);
      expect(retrievedWallet!.name, 'Test Wallet');
    });

    test('should create and retrieve category', () async {
      // Create a category
      final category = await database.categoryDao.createCategory(
        name: 'Test Category',
        type: 'expense',
        monthlyBudget: 500.0,
      );

      expect(category.name, 'Test Category');
      expect(category.type, 'expense');
      expect(category.monthlyBudget, 500.0);

      // Retrieve the category
      final retrievedCategory = await database.categoryDao.getCategoryById(
        category.id,
      );
      expect(retrievedCategory, isNotNull);
      expect(retrievedCategory!.name, 'Test Category');
    });

    test('should create transaction and update wallet balance', () async {
      // Create wallet and category first
      final wallet = await database.walletDao.createWallet(
        'Test Wallet',
        initialBalance: 100.0,
      );
      final category = await database.categoryDao.createCategory(
        name: 'Test Category',
        type: 'expense',
      );

      // Create a transaction
      final transaction = await database.transactionDao.createTransaction(
        amount: 50.0,
        type: 'expense',
        categoryId: category.id,
        walletId: wallet.id,
        notes: 'Test transaction',
      );

      expect(transaction.amount, 50.0);
      expect(transaction.type, 'expense');
      expect(transaction.notes, 'Test transaction');

      // Check that wallet balance was updated
      final updatedWallet = await database.walletDao.getWalletById(wallet.id);
      expect(updatedWallet!.balance, 50.0); // 100 - 50 = 50
    });

    test('should create recurring transaction', () async {
      // Create wallet and category first
      final wallet = await database.walletDao.createWallet('Test Wallet');
      final category = await database.categoryDao.createCategory(
        name: 'Test Category',
        type: 'expense',
      );

      // Create a recurring transaction
      final recurringTransaction = await database.recurringTransactionDao
          .createRecurringTransaction(
            amount: 100.0,
            type: 'expense',
            categoryId: category.id,
            walletId: wallet.id,
            frequency: 'monthly',
            description: 'Test recurring transaction',
          );

      expect(recurringTransaction.amount, 100.0);
      expect(recurringTransaction.type, 'expense');
      expect(recurringTransaction.frequency, 'monthly');
      expect(recurringTransaction.description, 'Test recurring transaction');
      expect(recurringTransaction.isActive, true);
    });
  });
}
