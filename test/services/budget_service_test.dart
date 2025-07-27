import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:matcher/matcher.dart' as matcher;

import '../../lib/models/database.dart';
import '../../lib/services/budget_service.dart';
import '../../lib/services/budget_service_impl.dart';
import '../../lib/services/wallet_service.dart';
import '../../lib/services/wallet_service_impl.dart';

void main() {
  late MoneoDatabase database;
  late BudgetService budgetService;
  late WalletService walletService;
  late Wallet testWallet;

  setUp(() async {
    // Create in-memory database for testing
    database = MoneoDatabase.withExecutor(NativeDatabase.memory());
    budgetService = BudgetServiceImpl(database);
    walletService = WalletServiceImpl(database);

    // Create test wallet
    testWallet = await walletService.createWallet(
      'Test Wallet',
      initialBalance: 1000.0,
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('BudgetService Tests', () {
    group('Category Management', () {
      group('getAllCategories', () {
        test('should return default categories created by migration', () async {
          final categories = await budgetService.getAllCategories();
          expect(categories, isNotEmpty);

          // Check that we have income, expense, and savings categories
          final types = categories.map((c) => c.type).toSet();
          expect(types, containsAll(['income', 'expense', 'savings']));
        });
      });

      group('getCategoriesByType', () {
        test('should return categories of specified type', () async {
          final expenseCategories = await budgetService.getCategoriesByType(
            'expense',
          );
          expect(expenseCategories, isNotEmpty);

          for (final category in expenseCategories) {
            expect(category.type, equals('expense'));
          }
        });

        test('should throw exception for invalid type', () async {
          expect(
            () => budgetService.getCategoriesByType('invalid'),
            throwsA(
              isA<BudgetException>().having(
                (e) => e.code,
                'code',
                'INVALID_CATEGORY_TYPE',
              ),
            ),
          );
        });
      });

      group('createCategory', () {
        test('should create category successfully', () async {
          final category = await budgetService.createCategory(
            name: 'Test Category',
            type: 'expense',
            monthlyBudget: 100.0,
            color: '#FF0000',
          );

          expect(category.name, equals('Test Category'));
          expect(category.type, equals('expense'));
          expect(category.monthlyBudget, equals(100.0));
          expect(category.color, equals('#FF0000'));
        });

        test('should trim category name', () async {
          final category = await budgetService.createCategory(
            name: '  Test Category  ',
            type: 'expense',
          );

          expect(category.name, equals('Test Category'));
        });

        test('should throw exception for empty name', () async {
          expect(
            () => budgetService.createCategory(name: '', type: 'expense'),
            throwsA(
              isA<BudgetException>().having(
                (e) => e.code,
                'code',
                'INVALID_CATEGORY_NAME',
              ),
            ),
          );
        });

        test('should throw exception for name too long', () async {
          final longName = 'a' * 51;
          expect(
            () => budgetService.createCategory(name: longName, type: 'expense'),
            throwsA(
              isA<BudgetException>().having(
                (e) => e.code,
                'code',
                'CATEGORY_NAME_TOO_LONG',
              ),
            ),
          );
        });

        test('should throw exception for invalid type', () async {
          expect(
            () => budgetService.createCategory(name: 'Test', type: 'invalid'),
            throwsA(
              isA<BudgetException>().having(
                (e) => e.code,
                'code',
                'INVALID_CATEGORY_TYPE',
              ),
            ),
          );
        });

        test('should throw exception for negative budget', () async {
          expect(
            () => budgetService.createCategory(
              name: 'Test',
              type: 'expense',
              monthlyBudget: -10.0,
            ),
            throwsA(
              isA<BudgetException>().having(
                (e) => e.code,
                'code',
                'INVALID_MONTHLY_BUDGET',
              ),
            ),
          );
        });

        test('should throw exception for invalid color', () async {
          expect(
            () => budgetService.createCategory(
              name: 'Test',
              type: 'expense',
              color: 'invalid',
            ),
            throwsA(
              isA<BudgetException>().having(
                (e) => e.code,
                'code',
                'INVALID_COLOR',
              ),
            ),
          );
        });
      });

      group('updateCategory', () {
        late Category testCategory;

        setUp(() async {
          testCategory = await budgetService.createCategory(
            name: 'Original Category',
            type: 'expense',
            monthlyBudget: 100.0,
          );
        });

        test('should update category name', () async {
          await budgetService.updateCategory(
            testCategory.id,
            name: 'Updated Category',
          );

          final updatedCategory = await budgetService.getCategoryById(
            testCategory.id,
          );
          expect(updatedCategory?.name, equals('Updated Category'));
        });

        test('should update monthly budget', () async {
          await budgetService.updateCategory(
            testCategory.id,
            monthlyBudget: 200.0,
          );

          final updatedCategory = await budgetService.getCategoryById(
            testCategory.id,
          );
          expect(updatedCategory?.monthlyBudget, equals(200.0));
        });

        test('should throw exception for non-existent category', () async {
          expect(
            () => budgetService.updateCategory(999, name: 'New Name'),
            throwsA(
              isA<BudgetException>().having(
                (e) => e.code,
                'code',
                'CATEGORY_NOT_FOUND',
              ),
            ),
          );
        });
      });

      group('deleteCategory', () {
        test('should delete category without transactions', () async {
          final category = await budgetService.createCategory(
            name: 'Test Category',
            type: 'expense',
          );

          await budgetService.deleteCategory(category.id);

          final deletedCategory = await budgetService.getCategoryById(
            category.id,
          );
          expect(deletedCategory, matcher.isNull);
        });

        test('should throw exception for non-existent category', () async {
          expect(
            () => budgetService.deleteCategory(999),
            throwsA(
              isA<BudgetException>().having(
                (e) => e.code,
                'code',
                'CATEGORY_NOT_FOUND',
              ),
            ),
          );
        });
      });
    });

    group('Budget Tracking', () {
      group('getCategorySpending', () {
        test('should return 0 for category with no transactions', () async {
          final categories = await budgetService.getCategoriesByType('expense');
          final category = categories.first;

          final spending = await budgetService.getCategorySpending(
            category.id,
            DateTime.now(),
          );

          expect(spending, equals(0.0));
        });

        test('should throw exception for non-existent category', () async {
          expect(
            () => budgetService.getCategorySpending(999, DateTime.now()),
            throwsA(
              isA<BudgetException>().having(
                (e) => e.code,
                'code',
                'CATEGORY_NOT_FOUND',
              ),
            ),
          );
        });
      });

      group('getBudgetProgress', () {
        test(
          'should return budget progress for all expense categories',
          () async {
            final budgetProgress = await budgetService.getBudgetProgress();
            expect(budgetProgress, isNotEmpty);

            for (final progress in budgetProgress) {
              expect(progress.category.type, equals('expense'));
            }
          },
        );
      });

      group('getTotalBudget', () {
        test('should calculate total budget from expense categories', () async {
          final totalBudget = await budgetService.getTotalBudget();
          expect(totalBudget, isA<double>());
          expect(totalBudget, greaterThanOrEqualTo(0.0));
        });
      });

      group('getTotalMonthlySpending', () {
        test('should return 0 when no transactions exist', () async {
          final totalSpending = await budgetService.getTotalMonthlySpending();
          expect(totalSpending, equals(0.0));
        });
      });
    });

    group('Recurring Transaction Management', () {
      group('getRecurringTransactions', () {
        test(
          'should return empty list when no recurring transactions exist',
          () async {
            final recurringTransactions =
                await budgetService.getRecurringTransactions();
            expect(recurringTransactions, isEmpty);
          },
        );
      });

      group('createRecurringTransaction', () {
        late Category expenseCategory;

        setUp(() async {
          final categories = await budgetService.getCategoriesByType('expense');
          expenseCategory = categories.first;
        });

        test('should create recurring transaction successfully', () async {
          final recurringTransaction = await budgetService
              .createRecurringTransaction(
                amount: 100.0,
                type: 'expense',
                categoryId: expenseCategory.id,
                walletId: testWallet.id,
                frequency: 'monthly',
                description: 'Test recurring expense',
              );

          expect(recurringTransaction.amount, equals(100.0));
          expect(recurringTransaction.type, equals('expense'));
          expect(recurringTransaction.categoryId, equals(expenseCategory.id));
          expect(recurringTransaction.walletId, equals(testWallet.id));
          expect(recurringTransaction.frequency, equals('monthly'));
          expect(
            recurringTransaction.description,
            equals('Test recurring expense'),
          );
          expect(recurringTransaction.isActive, isTrue);
        });

        test('should trim description', () async {
          final recurringTransaction = await budgetService
              .createRecurringTransaction(
                amount: 100.0,
                type: 'expense',
                categoryId: expenseCategory.id,
                walletId: testWallet.id,
                frequency: 'monthly',
                description: '  Test description  ',
              );

          expect(recurringTransaction.description, equals('Test description'));
        });

        test('should throw exception for invalid amount', () async {
          expect(
            () => budgetService.createRecurringTransaction(
              amount: 0.0,
              type: 'expense',
              categoryId: expenseCategory.id,
              walletId: testWallet.id,
              frequency: 'monthly',
              description: 'Test',
            ),
            throwsA(
              isA<BudgetException>().having(
                (e) => e.code,
                'code',
                'INVALID_AMOUNT',
              ),
            ),
          );
        });

        test('should throw exception for invalid type', () async {
          expect(
            () => budgetService.createRecurringTransaction(
              amount: 100.0,
              type: 'income', // Invalid for recurring transactions
              categoryId: expenseCategory.id,
              walletId: testWallet.id,
              frequency: 'monthly',
              description: 'Test',
            ),
            throwsA(
              isA<BudgetException>().having(
                (e) => e.code,
                'code',
                'INVALID_RECURRING_TYPE',
              ),
            ),
          );
        });

        test('should throw exception for invalid frequency', () async {
          expect(
            () => budgetService.createRecurringTransaction(
              amount: 100.0,
              type: 'expense',
              categoryId: expenseCategory.id,
              walletId: testWallet.id,
              frequency: 'daily', // Invalid frequency
              description: 'Test',
            ),
            throwsA(
              isA<BudgetException>().having(
                (e) => e.code,
                'code',
                'INVALID_FREQUENCY',
              ),
            ),
          );
        });

        test('should throw exception for empty description', () async {
          expect(
            () => budgetService.createRecurringTransaction(
              amount: 100.0,
              type: 'expense',
              categoryId: expenseCategory.id,
              walletId: testWallet.id,
              frequency: 'monthly',
              description: '',
            ),
            throwsA(
              isA<BudgetException>().having(
                (e) => e.code,
                'code',
                'INVALID_DESCRIPTION',
              ),
            ),
          );
        });

        test('should throw exception for non-existent wallet', () async {
          expect(
            () => budgetService.createRecurringTransaction(
              amount: 100.0,
              type: 'expense',
              categoryId: expenseCategory.id,
              walletId: 999,
              frequency: 'monthly',
              description: 'Test',
            ),
            throwsA(
              isA<BudgetException>().having(
                (e) => e.code,
                'code',
                'WALLET_NOT_FOUND',
              ),
            ),
          );
        });

        test('should throw exception for non-existent category', () async {
          expect(
            () => budgetService.createRecurringTransaction(
              amount: 100.0,
              type: 'expense',
              categoryId: 999,
              walletId: testWallet.id,
              frequency: 'monthly',
              description: 'Test',
            ),
            throwsA(
              isA<BudgetException>().having(
                (e) => e.code,
                'code',
                'CATEGORY_NOT_FOUND',
              ),
            ),
          );
        });
      });

      group('updateRecurringTransaction', () {
        late RecurringTransaction testRecurringTransaction;
        late Category expenseCategory;

        setUp(() async {
          final categories = await budgetService.getCategoriesByType('expense');
          expenseCategory = categories.first;

          testRecurringTransaction = await budgetService
              .createRecurringTransaction(
                amount: 100.0,
                type: 'expense',
                categoryId: expenseCategory.id,
                walletId: testWallet.id,
                frequency: 'monthly',
                description: 'Original description',
              );
        });

        test('should update recurring transaction amount', () async {
          await budgetService.updateRecurringTransaction(
            testRecurringTransaction.id,
            amount: 150.0,
          );

          final updatedTransaction = await budgetService
              .getRecurringTransactionById(testRecurringTransaction.id);
          expect(
            updatedTransaction?.recurringTransaction.amount,
            equals(150.0),
          );
        });

        test('should update recurring transaction description', () async {
          await budgetService.updateRecurringTransaction(
            testRecurringTransaction.id,
            description: 'Updated description',
          );

          final updatedTransaction = await budgetService
              .getRecurringTransactionById(testRecurringTransaction.id);
          expect(
            updatedTransaction?.recurringTransaction.description,
            equals('Updated description'),
          );
        });

        test(
          'should throw exception for non-existent recurring transaction',
          () async {
            expect(
              () =>
                  budgetService.updateRecurringTransaction(999, amount: 100.0),
              throwsA(
                isA<BudgetException>().having(
                  (e) => e.code,
                  'code',
                  'RECURRING_TRANSACTION_NOT_FOUND',
                ),
              ),
            );
          },
        );
      });

      group('deleteRecurringTransaction', () {
        test('should delete recurring transaction successfully', () async {
          final categories = await budgetService.getCategoriesByType('expense');
          final expenseCategory = categories.first;

          final recurringTransaction = await budgetService
              .createRecurringTransaction(
                amount: 100.0,
                type: 'expense',
                categoryId: expenseCategory.id,
                walletId: testWallet.id,
                frequency: 'monthly',
                description: 'Test recurring expense',
              );

          await budgetService.deleteRecurringTransaction(
            recurringTransaction.id,
          );

          final deletedTransaction = await budgetService
              .getRecurringTransactionById(recurringTransaction.id);
          expect(deletedTransaction, matcher.isNull);
        });

        test(
          'should throw exception for non-existent recurring transaction',
          () async {
            expect(
              () => budgetService.deleteRecurringTransaction(999),
              throwsA(
                isA<BudgetException>().having(
                  (e) => e.code,
                  'code',
                  'RECURRING_TRANSACTION_NOT_FOUND',
                ),
              ),
            );
          },
        );
      });

      group('processRecurringTransactions', () {
        test('should return 0 when no due transactions exist', () async {
          final processedCount =
              await budgetService.processRecurringTransactions();
          expect(processedCount, equals(0));
        });
      });

      group('getDueRecurringTransactions', () {
        test(
          'should return empty list when no due transactions exist',
          () async {
            final dueTransactions =
                await budgetService.getDueRecurringTransactions();
            expect(dueTransactions, isEmpty);
          },
        );
      });
    });

    group('Stream methods', () {
      test('watchAllCategories should emit category updates', () async {
        final stream = budgetService.watchAllCategories();

        // Get initial categories (default ones from migration)
        final initialCategories = await stream.first;
        expect(initialCategories, isNotEmpty);

        // Create a new category
        await budgetService.createCategory(
          name: 'Test Category',
          type: 'expense',
        );

        // Should emit updated list
        final updatedCategories = await stream.first;
        expect(updatedCategories.length, greaterThan(initialCategories.length));
      });

      test(
        'watchCategoriesByType should emit type-specific category updates',
        () async {
          final stream = budgetService.watchCategoriesByType('expense');

          // Get initial expense categories
          final initialCategories = await stream.first;
          expect(initialCategories, isNotEmpty);

          // Create a new expense category
          await budgetService.createCategory(
            name: 'Test Expense Category',
            type: 'expense',
          );

          // Should emit updated list
          final updatedCategories = await stream.first;
          expect(
            updatedCategories.length,
            greaterThan(initialCategories.length),
          );

          // All categories should be expense type
          for (final category in updatedCategories) {
            expect(category.type, equals('expense'));
          }
        },
      );

      test(
        'watchCategoriesByType should throw exception for invalid type',
        () async {
          expect(
            () => budgetService.watchCategoriesByType('invalid'),
            throwsA(
              isA<BudgetException>().having(
                (e) => e.code,
                'code',
                'INVALID_CATEGORY_TYPE',
              ),
            ),
          );
        },
      );
    });
  });
}
