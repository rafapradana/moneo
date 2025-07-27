import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// Import DAO classes
import 'dao/wallet_dao.dart';
import 'dao/category_dao.dart';
import 'dao/transaction_dao.dart';
import 'dao/recurring_transaction_dao.dart';

// Import table definitions
part 'database.g.dart';

// Wallets table definition
@DataClassName('Wallet')
class Wallets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  RealColumn get balance => real().withDefault(const Constant(0.0))();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

// Categories table definition
@DataClassName('Category')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get type => text()();
  RealColumn get monthlyBudget => real().nullable()();
  TextColumn get color => text().withDefault(const Constant('#2196F3'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// Transactions table definition
@DataClassName('Transaction')
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get amount => real()();
  TextColumn get type => text()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  IntColumn get walletId => integer().references(Wallets, #id)();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get transactionDate => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// Recurring transactions table definition
@DataClassName('RecurringTransaction')
class RecurringTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get amount => real()();
  TextColumn get type => text()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  IntColumn get walletId => integer().references(Wallets, #id)();
  TextColumn get frequency => text()();
  DateTimeColumn get nextDue => dateTime()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get description => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// Database class
@DriftDatabase(
  tables: [Wallets, Categories, Transactions, RecurringTransactions],
  daos: [WalletDao, CategoryDao, TransactionDao, RecurringTransactionDao],
)
class MoneoDatabase extends _$MoneoDatabase {
  MoneoDatabase() : super(_openConnection());

  // Constructor for testing with custom executor
  MoneoDatabase.withExecutor(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();

        // Insert default categories
        await _insertDefaultCategories();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Handle future schema upgrades
      },
    );
  }

  // Insert default categories for new installations
  Future<void> _insertDefaultCategories() async {
    final defaultCategories = [
      // Income categories
      CategoriesCompanion.insert(
        name: 'Salary',
        type: 'income',
        color: const Value('#4CAF50'),
      ),
      CategoriesCompanion.insert(
        name: 'Freelance',
        type: 'income',
        color: const Value('#8BC34A'),
      ),
      CategoriesCompanion.insert(
        name: 'Investment',
        type: 'income',
        color: const Value('#CDDC39'),
      ),

      // Expense categories
      CategoriesCompanion.insert(
        name: 'Food & Dining',
        type: 'expense',
        monthlyBudget: const Value(500.0),
        color: const Value('#FF5722'),
      ),
      CategoriesCompanion.insert(
        name: 'Transportation',
        type: 'expense',
        monthlyBudget: const Value(200.0),
        color: const Value('#FF9800'),
      ),
      CategoriesCompanion.insert(
        name: 'Shopping',
        type: 'expense',
        monthlyBudget: const Value(300.0),
        color: const Value('#E91E63'),
      ),
      CategoriesCompanion.insert(
        name: 'Entertainment',
        type: 'expense',
        monthlyBudget: const Value(150.0),
        color: const Value('#9C27B0'),
      ),
      CategoriesCompanion.insert(
        name: 'Bills & Utilities',
        type: 'expense',
        monthlyBudget: const Value(400.0),
        color: const Value('#607D8B'),
      ),
      CategoriesCompanion.insert(
        name: 'Healthcare',
        type: 'expense',
        monthlyBudget: const Value(200.0),
        color: const Value('#F44336'),
      ),

      // Savings categories
      CategoriesCompanion.insert(
        name: 'Emergency Fund',
        type: 'savings',
        color: const Value('#2196F3'),
      ),
      CategoriesCompanion.insert(
        name: 'Vacation',
        type: 'savings',
        color: const Value('#00BCD4'),
      ),
      CategoriesCompanion.insert(
        name: 'Investment Savings',
        type: 'savings',
        color: const Value('#009688'),
      ),
    ];

    for (final category in defaultCategories) {
      await into(categories).insert(category);
    }
  }
}

// Database connection setup
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'moneo.db'));
    return NativeDatabase.createInBackground(file);
  });
}
