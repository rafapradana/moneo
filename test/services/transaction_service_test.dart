import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:matcher/matcher.dart' as matcher;

import '../../lib/models/database.dart';
import '../../lib/services/transaction_service.dart';
import '../../lib/services/transaction_service_impl.dart';
import '../../lib/services/wallet_service.dart';
import '../../lib/services/wallet_service_impl.dart';

void main() {
  late MoneoDatabase database;
  late TransactionService transactionService;
  late WalletService walletService;
  late Wallet testWallet;
  late Category incomeCategory;
  late Category expenseCategory;

  setUp(() async {
    // Create in-memory database for testing
    database = MoneoDatabase.withExecutor(NativeDatabase.memory());
    transactionService = TransactionServiceImpl(database);
    walletService = WalletServiceImpl(database);

    // Create test data
    testWallet = await walletService.createWallet(
      'Test Wallet',
      initialBalance: 1000.0,
    );

    // Get default categories created by database migration
    final categories = await database.categoryDao.getAllCategories();
    incomeCategory = categories.firstWhere((c) => c.type == 'income');
    expenseCategory = categories.firstWhere((c) => c.type == 'expense');
  });

  tearDown(() async {
    await database.close();
  });

  group('TransactionService Tests', () {
    group('getAllTransactions', () {
      test('should return empty list when no transactions exist', () async {
        final transactions = await transactionService.getAllTransactions();
        expect(transactions, isEmpty);
      });

      test('should return all transactions ordered by date', () async {
        // Create test transactions with specific dates
        final now = DateTime.now();
        final earlier = now.subtract(const Duration(hours: 1));

        final transaction1 = await transactionService.createTransaction(
          amount: 100.0,
          type: 'income',
          categoryId: incomeCategory.id,
          walletId: testWallet.id,
          transactionDate: earlier,
        );

        final transaction2 = await transactionService.createTransaction(
          amount: 50.0,
          type: 'expense',
          categoryId: expenseCategory.id,
          walletId: testWallet.id,
          transactionDate: now,
        );

        final transactions = await transactionService.getAllTransactions();
        expect(transactions, hasLength(2));

        // Should be ordered by date (newest first)
        expect(
          transactions[0].transaction.transactionDate.isAfter(
                transactions[1].transaction.transactionDate,
              ) ||
              transactions[0].transaction.transactionDate.isAtSameMomentAs(
                transactions[1].transaction.transactionDate,
              ),
          isTrue,
        );

        // Verify both transactions are present
        final amounts = transactions.map((t) => t.transaction.amount).toList();
        expect(amounts, containsAll([100.0, 50.0]));
      });
    });

    group('getRecentTransactions', () {
      test('should return limited number of transactions', () async {
        // Create 5 transactions
        for (int i = 1; i <= 5; i++) {
          await transactionService.createTransaction(
            amount: i * 10.0,
            type: 'income',
            categoryId: incomeCategory.id,
            walletId: testWallet.id,
          );
          await Future.delayed(const Duration(milliseconds: 1));
        }

        final recentTransactions = await transactionService
            .getRecentTransactions(3);
        expect(recentTransactions, hasLength(3));

        // Should be ordered by date (newest first)
        expect(
          recentTransactions[0].transaction.transactionDate.isAfter(
                recentTransactions[1].transaction.transactionDate,
              ) ||
              recentTransactions[0].transaction.transactionDate
                  .isAtSameMomentAs(
                    recentTransactions[1].transaction.transactionDate,
                  ),
          isTrue,
        );

        expect(
          recentTransactions[1].transaction.transactionDate.isAfter(
                recentTransactions[2].transaction.transactionDate,
              ) ||
              recentTransactions[1].transaction.transactionDate
                  .isAtSameMomentAs(
                    recentTransactions[2].transaction.transactionDate,
                  ),
          isTrue,
        );
      });

      test('should throw exception for invalid limit', () async {
        expect(
          () => transactionService.getRecentTransactions(0),
          throwsA(
            isA<TransactionException>().having(
              (e) => e.code,
              'code',
              'INVALID_LIMIT',
            ),
          ),
        );

        expect(
          () => transactionService.getRecentTransactions(-1),
          throwsA(
            isA<TransactionException>().having(
              (e) => e.code,
              'code',
              'INVALID_LIMIT',
            ),
          ),
        );
      });
    });

    group('createTransaction', () {
      test('should create income transaction successfully', () async {
        final transaction = await transactionService.createTransaction(
          amount: 100.0,
          type: 'income',
          categoryId: incomeCategory.id,
          walletId: testWallet.id,
          notes: 'Test income',
        );

        expect(transaction.amount, equals(100.0));
        expect(transaction.type, equals('income'));
        expect(transaction.categoryId, equals(incomeCategory.id));
        expect(transaction.walletId, equals(testWallet.id));
        expect(transaction.notes, equals('Test income'));

        // Check wallet balance was updated
        final updatedWallet = await walletService.getWalletById(testWallet.id);
        expect(updatedWallet?.balance, equals(1100.0));
      });

      test('should create expense transaction successfully', () async {
        final transaction = await transactionService.createTransaction(
          amount: 50.0,
          type: 'expense',
          categoryId: expenseCategory.id,
          walletId: testWallet.id,
          notes: 'Test expense',
        );

        expect(transaction.amount, equals(50.0));
        expect(transaction.type, equals('expense'));
        expect(transaction.categoryId, equals(expenseCategory.id));
        expect(transaction.walletId, equals(testWallet.id));
        expect(transaction.notes, equals('Test expense'));

        // Check wallet balance was updated
        final updatedWallet = await walletService.getWalletById(testWallet.id);
        expect(updatedWallet?.balance, equals(950.0));
      });

      test('should trim notes', () async {
        final transaction = await transactionService.createTransaction(
          amount: 100.0,
          type: 'income',
          categoryId: incomeCategory.id,
          walletId: testWallet.id,
          notes: '  Test notes  ',
        );

        expect(transaction.notes, equals('Test notes'));
      });

      test('should throw exception for invalid amount', () async {
        expect(
          () => transactionService.createTransaction(
            amount: 0.0,
            type: 'income',
            categoryId: incomeCategory.id,
            walletId: testWallet.id,
          ),
          throwsA(
            isA<TransactionException>().having(
              (e) => e.code,
              'code',
              'INVALID_AMOUNT',
            ),
          ),
        );

        expect(
          () => transactionService.createTransaction(
            amount: -10.0,
            type: 'income',
            categoryId: incomeCategory.id,
            walletId: testWallet.id,
          ),
          throwsA(
            isA<TransactionException>().having(
              (e) => e.code,
              'code',
              'INVALID_AMOUNT',
            ),
          ),
        );
      });

      test('should throw exception for invalid transaction type', () async {
        expect(
          () => transactionService.createTransaction(
            amount: 100.0,
            type: 'invalid',
            categoryId: incomeCategory.id,
            walletId: testWallet.id,
          ),
          throwsA(
            isA<TransactionException>().having(
              (e) => e.code,
              'code',
              'INVALID_TRANSACTION_TYPE',
            ),
          ),
        );
      });

      test('should throw exception for non-existent wallet', () async {
        expect(
          () => transactionService.createTransaction(
            amount: 100.0,
            type: 'income',
            categoryId: incomeCategory.id,
            walletId: 999,
          ),
          throwsA(
            isA<TransactionException>().having(
              (e) => e.code,
              'code',
              'WALLET_NOT_FOUND',
            ),
          ),
        );
      });

      test('should throw exception for non-existent category', () async {
        expect(
          () => transactionService.createTransaction(
            amount: 100.0,
            type: 'income',
            categoryId: 999,
            walletId: testWallet.id,
          ),
          throwsA(
            isA<TransactionException>().having(
              (e) => e.code,
              'code',
              'CATEGORY_NOT_FOUND',
            ),
          ),
        );
      });

      test('should throw exception for insufficient balance', () async {
        expect(
          () => transactionService.createTransaction(
            amount: 2000.0, // More than wallet balance
            type: 'expense',
            categoryId: expenseCategory.id,
            walletId: testWallet.id,
          ),
          throwsA(
            isA<TransactionException>().having(
              (e) => e.code,
              'code',
              'INSUFFICIENT_BALANCE',
            ),
          ),
        );
      });

      test('should throw exception for notes too long', () async {
        final longNotes = 'a' * 501;
        expect(
          () => transactionService.createTransaction(
            amount: 100.0,
            type: 'income',
            categoryId: incomeCategory.id,
            walletId: testWallet.id,
            notes: longNotes,
          ),
          throwsA(
            isA<TransactionException>().having(
              (e) => e.code,
              'code',
              'NOTES_TOO_LONG',
            ),
          ),
        );
      });

      test('should throw exception for invalid category type', () async {
        expect(
          () => transactionService.createTransaction(
            amount: 100.0,
            type: 'income',
            categoryId: expenseCategory.id, // Using expense category for income
            walletId: testWallet.id,
          ),
          throwsA(
            isA<TransactionException>().having(
              (e) => e.code,
              'code',
              'INVALID_CATEGORY_TYPE',
            ),
          ),
        );

        expect(
          () => transactionService.createTransaction(
            amount: 100.0,
            type: 'expense',
            categoryId: incomeCategory.id, // Using income category for expense
            walletId: testWallet.id,
          ),
          throwsA(
            isA<TransactionException>().having(
              (e) => e.code,
              'code',
              'INVALID_CATEGORY_TYPE',
            ),
          ),
        );
      });
    });

    group('updateTransaction', () {
      late Transaction testTransaction;

      setUp(() async {
        testTransaction = await transactionService.createTransaction(
          amount: 100.0,
          type: 'income',
          categoryId: incomeCategory.id,
          walletId: testWallet.id,
          notes: 'Original notes',
        );
      });

      test('should update transaction amount', () async {
        await transactionService.updateTransaction(
          testTransaction.id,
          amount: 150.0,
        );

        final updatedTransaction = await transactionService.getTransactionById(
          testTransaction.id,
        );
        expect(updatedTransaction?.transaction.amount, equals(150.0));
      });

      test('should update transaction notes', () async {
        await transactionService.updateTransaction(
          testTransaction.id,
          notes: 'Updated notes',
        );

        final updatedTransaction = await transactionService.getTransactionById(
          testTransaction.id,
        );
        expect(updatedTransaction?.transaction.notes, equals('Updated notes'));
      });

      test('should throw exception for non-existent transaction', () async {
        expect(
          () => transactionService.updateTransaction(999, amount: 100.0),
          throwsA(
            isA<TransactionException>().having(
              (e) => e.code,
              'code',
              'TRANSACTION_NOT_FOUND',
            ),
          ),
        );
      });

      test('should throw exception for invalid amount', () async {
        expect(
          () => transactionService.updateTransaction(
            testTransaction.id,
            amount: 0.0,
          ),
          throwsA(
            isA<TransactionException>().having(
              (e) => e.code,
              'code',
              'INVALID_AMOUNT',
            ),
          ),
        );
      });
    });

    group('deleteTransaction', () {
      test('should delete transaction successfully', () async {
        final transaction = await transactionService.createTransaction(
          amount: 100.0,
          type: 'income',
          categoryId: incomeCategory.id,
          walletId: testWallet.id,
        );

        await transactionService.deleteTransaction(transaction.id);

        final deletedTransaction = await transactionService.getTransactionById(
          transaction.id,
        );
        expect(deletedTransaction, matcher.isNull);
      });

      test('should throw exception for non-existent transaction', () async {
        expect(
          () => transactionService.deleteTransaction(999),
          throwsA(
            isA<TransactionException>().having(
              (e) => e.code,
              'code',
              'TRANSACTION_NOT_FOUND',
            ),
          ),
        );
      });
    });

    group('getFilteredTransactions', () {
      late Transaction incomeTransaction;
      late Transaction expenseTransaction;

      setUp(() async {
        incomeTransaction = await transactionService.createTransaction(
          amount: 100.0,
          type: 'income',
          categoryId: incomeCategory.id,
          walletId: testWallet.id,
        );

        expenseTransaction = await transactionService.createTransaction(
          amount: 50.0,
          type: 'expense',
          categoryId: expenseCategory.id,
          walletId: testWallet.id,
        );
      });

      test('should filter by category', () async {
        final incomeTransactions = await transactionService
            .getFilteredTransactions(categoryId: incomeCategory.id);

        expect(incomeTransactions, hasLength(1));
        expect(
          incomeTransactions[0].transaction.id,
          equals(incomeTransaction.id),
        );
      });

      test('should filter by wallet', () async {
        final walletTransactions = await transactionService
            .getFilteredTransactions(walletId: testWallet.id);

        expect(walletTransactions, hasLength(2));
      });

      test('should filter by date range', () async {
        final now = DateTime.now();
        final yesterday = now.subtract(const Duration(days: 1));
        final tomorrow = now.add(const Duration(days: 1));

        final todayTransactions = await transactionService
            .getFilteredTransactions(startDate: yesterday, endDate: tomorrow);

        expect(todayTransactions, hasLength(2));
      });

      test('should throw exception for invalid date range', () async {
        final now = DateTime.now();
        final yesterday = now.subtract(const Duration(days: 1));

        expect(
          () => transactionService.getFilteredTransactions(
            startDate: now,
            endDate: yesterday, // End date before start date
          ),
          throwsA(
            isA<TransactionException>().having(
              (e) => e.code,
              'code',
              'INVALID_DATE_RANGE',
            ),
          ),
        );
      });
    });

    group('getTransactionById', () {
      test('should return transaction when it exists', () async {
        final createdTransaction = await transactionService.createTransaction(
          amount: 100.0,
          type: 'income',
          categoryId: incomeCategory.id,
          walletId: testWallet.id,
        );

        final foundTransaction = await transactionService.getTransactionById(
          createdTransaction.id,
        );

        expect(foundTransaction, matcher.isNotNull);
        expect(foundTransaction?.transaction.id, equals(createdTransaction.id));
        expect(foundTransaction?.transaction.amount, equals(100.0));
      });

      test('should return null when transaction does not exist', () async {
        final transaction = await transactionService.getTransactionById(999);
        expect(transaction, matcher.isNull);
      });
    });

    group('Stream methods', () {
      test('watchAllTransactions should emit transaction updates', () async {
        final stream = transactionService.watchAllTransactions();

        // Initial state - empty
        expect(await stream.first, isEmpty);

        // Create a transaction
        await transactionService.createTransaction(
          amount: 100.0,
          type: 'income',
          categoryId: incomeCategory.id,
          walletId: testWallet.id,
        );

        // Should emit updated list
        final transactions = await stream.first;
        expect(transactions, hasLength(1));
        expect(transactions[0].transaction.amount, equals(100.0));
      });

      test(
        'watchRecentTransactions should emit recent transaction updates',
        () async {
          final stream = transactionService.watchRecentTransactions(5);

          // Initial state - empty
          expect(await stream.first, isEmpty);

          // Create transactions
          await transactionService.createTransaction(
            amount: 100.0,
            type: 'income',
            categoryId: incomeCategory.id,
            walletId: testWallet.id,
          );

          // Should emit updated list
          final recentTransactions = await stream.first;
          expect(recentTransactions, hasLength(1));
          expect(recentTransactions[0].transaction.amount, equals(100.0));
        },
      );

      test(
        'watchRecentTransactions should throw exception for invalid limit',
        () async {
          expect(
            () => transactionService.watchRecentTransactions(0),
            throwsA(
              isA<TransactionException>().having(
                (e) => e.code,
                'code',
                'INVALID_LIMIT',
              ),
            ),
          );
        },
      );
    });
  });
}
