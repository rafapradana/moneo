import 'package:drift/drift.dart';
import '../database.dart';

part 'category_dao.g.dart';

@DriftAccessor(tables: [Categories, Transactions])
class CategoryDao extends DatabaseAccessor<MoneoDatabase>
    with _$CategoryDaoMixin {
  CategoryDao(super.db);

  // Get all categories ordered by name
  Future<List<Category>> getAllCategories() {
    return (select(categories)
      ..orderBy([(c) => OrderingTerm.asc(c.name)])).get();
  }

  // Get categories by type
  Future<List<Category>> getCategoriesByType(String type) {
    return (select(categories)
          ..where((c) => c.type.equals(type))
          ..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .get();
  }

  // Get income categories
  Future<List<Category>> getIncomeCategories() {
    return getCategoriesByType('income');
  }

  // Get expense categories
  Future<List<Category>> getExpenseCategories() {
    return getCategoriesByType('expense');
  }

  // Get savings categories
  Future<List<Category>> getSavingsCategories() {
    return getCategoriesByType('savings');
  }

  // Get category by ID
  Future<Category?> getCategoryById(int id) {
    return (select(categories)
      ..where((c) => c.id.equals(id))).getSingleOrNull();
  }

  // Create a new category
  Future<Category> createCategory({
    required String name,
    required String type,
    double? monthlyBudget,
    String color = '#2196F3',
  }) async {
    final categoryId = await into(categories).insert(
      CategoriesCompanion.insert(
        name: name,
        type: type,
        monthlyBudget:
            monthlyBudget != null ? Value(monthlyBudget) : const Value.absent(),
        color: Value(color),
      ),
    );

    return (await getCategoryById(categoryId))!;
  }

  // Update category
  Future<bool> updateCategory(
    int id, {
    String? name,
    String? type,
    double? monthlyBudget,
    String? color,
  }) async {
    final companion = CategoriesCompanion(
      name: name != null ? Value(name) : const Value.absent(),
      type: type != null ? Value(type) : const Value.absent(),
      monthlyBudget:
          monthlyBudget != null ? Value(monthlyBudget) : const Value.absent(),
      color: color != null ? Value(color) : const Value.absent(),
    );

    final result = await (update(categories)
      ..where((c) => c.id.equals(id))).write(companion);
    return result > 0;
  }

  // Delete category (only if no transactions exist)
  Future<bool> deleteCategory(int id) async {
    // Check if category has transactions
    final transactionCount =
        await (selectOnly(transactions)
              ..addColumns([transactions.id.count()])
              ..where(transactions.categoryId.equals(id)))
            .getSingle();

    if ((transactionCount.read(transactions.id.count()) ?? 0) > 0) {
      return false; // Cannot delete category with transactions
    }

    final result =
        await (delete(categories)..where((c) => c.id.equals(id))).go();
    return result > 0;
  }

  // Get category spending for a specific month
  Future<double> getCategorySpending(int categoryId, DateTime month) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    final result =
        await (selectOnly(transactions)
              ..addColumns([transactions.amount.sum()])
              ..where(transactions.categoryId.equals(categoryId))
              ..where(transactions.type.equals('expense'))
              ..where(
                transactions.transactionDate.isBetweenValues(
                  startOfMonth,
                  endOfMonth,
                ),
              ))
            .getSingle();

    return result.read(transactions.amount.sum()) ?? 0.0;
  }

  // Get category spending for current month
  Future<double> getCurrentMonthCategorySpending(int categoryId) async {
    final now = DateTime.now();
    return getCategorySpending(categoryId, now);
  }

  // Get budget progress for all expense categories
  Future<List<CategoryBudgetProgress>> getBudgetProgress([
    DateTime? month,
  ]) async {
    final targetMonth = month ?? DateTime.now();
    final expenseCategories = await getExpenseCategories();
    final List<CategoryBudgetProgress> progressList = [];

    for (final category in expenseCategories) {
      final spending = await getCategorySpending(category.id, targetMonth);
      progressList.add(
        CategoryBudgetProgress(
          category: category,
          spent: spending,
          budget: category.monthlyBudget ?? 0.0,
          month: targetMonth,
        ),
      );
    }

    return progressList;
  }

  // Get categories with spending summary
  Future<List<CategoryWithSpending>> getCategoriesWithSpending([
    DateTime? month,
  ]) async {
    final targetMonth = month ?? DateTime.now();
    final startOfMonth = DateTime(targetMonth.year, targetMonth.month, 1);
    final endOfMonth = DateTime(
      targetMonth.year,
      targetMonth.month + 1,
      0,
      23,
      59,
      59,
    );

    final query = select(categories).join([
      leftOuterJoin(
        transactions,
        transactions.categoryId.equalsExp(categories.id) &
            transactions.transactionDate.isBetweenValues(
              startOfMonth,
              endOfMonth,
            ),
      ),
    ]);

    final results = await query.get();
    final Map<int, CategoryWithSpending> categoryMap = {};

    for (final row in results) {
      final category = row.readTable(categories);
      final transaction = row.readTableOrNull(transactions);

      if (!categoryMap.containsKey(category.id)) {
        categoryMap[category.id] = CategoryWithSpending(
          category: category,
          totalSpent: 0.0,
          transactionCount: 0,
          month: targetMonth,
        );
      }

      if (transaction != null) {
        final currentSpending = categoryMap[category.id]!;
        categoryMap[category.id] = currentSpending.copyWith(
          totalSpent: currentSpending.totalSpent + transaction.amount,
          transactionCount: currentSpending.transactionCount + 1,
        );
      }
    }

    return categoryMap.values.toList()
      ..sort((a, b) => a.category.name.compareTo(b.category.name));
  }

  // Get overspent categories for current month
  Future<List<Category>> getOverspentCategories([DateTime? month]) async {
    final budgetProgress = await getBudgetProgress(month);
    return budgetProgress
        .where((progress) => progress.isOverBudget)
        .map((progress) => progress.category)
        .toList();
  }

  // Get total budget for all expense categories
  Future<double> getTotalBudget() async {
    final result =
        await (selectOnly(categories)
              ..addColumns([categories.monthlyBudget.sum()])
              ..where(categories.type.equals('expense'))
              ..where(categories.monthlyBudget.isNotNull()))
            .getSingle();

    return result.read(categories.monthlyBudget.sum()) ?? 0.0;
  }

  // Get total spending for current month
  Future<double> getTotalMonthlySpending([DateTime? month]) async {
    final targetMonth = month ?? DateTime.now();
    final startOfMonth = DateTime(targetMonth.year, targetMonth.month, 1);
    final endOfMonth = DateTime(
      targetMonth.year,
      targetMonth.month + 1,
      0,
      23,
      59,
      59,
    );

    final result =
        await (selectOnly(transactions)
              ..addColumns([transactions.amount.sum()])
              ..where(transactions.type.equals('expense'))
              ..where(
                transactions.transactionDate.isBetweenValues(
                  startOfMonth,
                  endOfMonth,
                ),
              ))
            .getSingle();

    return result.read(transactions.amount.sum()) ?? 0.0;
  }

  // Watch all categories (for reactive UI)
  Stream<List<Category>> watchAllCategories() {
    return (select(categories)
      ..orderBy([(c) => OrderingTerm.asc(c.name)])).watch();
  }

  // Watch categories by type
  Stream<List<Category>> watchCategoriesByType(String type) {
    return (select(categories)
          ..where((c) => c.type.equals(type))
          ..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .watch();
  }

  // Watch budget progress
  Stream<List<CategoryBudgetProgress>> watchBudgetProgress() async* {
    await for (final _
        in (select(transactions)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch()) {
      yield await getBudgetProgress();
    }
  }
}

// Helper class for category budget progress
class CategoryBudgetProgress {
  final Category category;
  final double spent;
  final double budget;
  final DateTime month;

  const CategoryBudgetProgress({
    required this.category,
    required this.spent,
    required this.budget,
    required this.month,
  });

  double get progress => budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;
  double get remaining => (budget - spent).clamp(0.0, budget);
  bool get isOverBudget => budget > 0 && spent > budget;
  bool get hasBudget => budget > 0;
  double get overAmount => isOverBudget ? spent - budget : 0.0;

  String get progressText {
    if (!hasBudget) return 'No budget set';
    return '\$${spent.toStringAsFixed(2)} / \$${budget.toStringAsFixed(2)}';
  }

  String get remainingText {
    if (!hasBudget) return 'No budget';
    if (isOverBudget) return 'Over by \$${overAmount.toStringAsFixed(2)}';
    return '\$${remaining.toStringAsFixed(2)} remaining';
  }
}

// Helper class for category with spending
class CategoryWithSpending {
  final Category category;
  final double totalSpent;
  final int transactionCount;
  final DateTime month;

  const CategoryWithSpending({
    required this.category,
    required this.totalSpent,
    required this.transactionCount,
    required this.month,
  });

  CategoryWithSpending copyWith({
    Category? category,
    double? totalSpent,
    int? transactionCount,
    DateTime? month,
  }) {
    return CategoryWithSpending(
      category: category ?? this.category,
      totalSpent: totalSpent ?? this.totalSpent,
      transactionCount: transactionCount ?? this.transactionCount,
      month: month ?? this.month,
    );
  }
}
