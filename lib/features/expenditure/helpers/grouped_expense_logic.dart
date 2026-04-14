import '../models/expenditure_item.dart' as domain;

/// Helper class for grouping expenses by category
class GroupedExpenseLogic {
  /// Groups expenses by category name and calculates totals
  static Map<String, List<domain.ExpenditureSubItem>> groupByCategory(
    List<domain.ExpenditureSubItem> expenses,
  ) {
    final Map<String, List<domain.ExpenditureSubItem>> groupedExpenses = {};
    
    for (final expense in expenses) {
      final categoryName = expense.category?.isNotEmpty == true 
          ? expense.category! 
          : 'Uncategorized';
      
      if (!groupedExpenses.containsKey(categoryName)) {
        groupedExpenses[categoryName] = [];
      }
      groupedExpenses[categoryName]!.add(expense);
    }
    
    return groupedExpenses;
  }
  
  /// Calculates the total amount for each category
  static Map<String, double> calculateCategoryTotals(
    Map<String, List<domain.ExpenditureSubItem>> groupedExpenses,
  ) {
    final Map<String, double> categoryTotals = {};
    
    for (final entry in groupedExpenses.entries) {
      final total = entry.value.fold<double>(
        0.0,
        (sum, expense) => sum + expense.amount,
      );
      categoryTotals[entry.key] = total;
    }
    
    return categoryTotals;
  }
  
  /// Gets sorted categories by total amount (descending)
  static List<String> getSortedCategoriesByTotal(
    Map<String, double> categoryTotals,
  ) {
    final sortedEntries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedEntries.map((entry) => entry.key).toList();
  }
  
  /// Gets all grouped data in a single call
  static GroupedExpenseData getGroupedExpenseData(
    List<domain.ExpenditureSubItem> expenses,
  ) {
    final groupedExpenses = groupByCategory(expenses);
    final categoryTotals = calculateCategoryTotals(groupedExpenses);
    final sortedCategories = getSortedCategoriesByTotal(categoryTotals);
    
    return GroupedExpenseData(
      groupedExpenses: groupedExpenses,
      categoryTotals: categoryTotals,
      sortedCategories: sortedCategories,
    );
  }
}

/// Data class to hold all grouped expense information
class GroupedExpenseData {
  final Map<String, List<domain.ExpenditureSubItem>> groupedExpenses;
  final Map<String, double> categoryTotals;
  final List<String> sortedCategories;
  
  const GroupedExpenseData({
    required this.groupedExpenses,
    required this.categoryTotals,
    required this.sortedCategories,
  });
  
  /// Gets the total amount across all categories
  double get grandTotal {
    return categoryTotals.values.fold(0.0, (sum, total) => sum + total);
  }
  
  /// Gets the number of categories
  int get categoryCount => sortedCategories.length;
  
  /// Gets expenses for a specific category
  List<domain.ExpenditureSubItem>? getExpensesForCategory(String category) {
    return groupedExpenses[category];
  }
  
  /// Gets the total for a specific category
  double? getTotalForCategory(String category) {
    return categoryTotals[category];
  }
}
