import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/font_utils.dart';
import 'package:shared/shared.dart';
import '../models/expenditure_item.dart' as domain;
import '../view_models/expenditure_view_model.dart';
import '../helpers/grouped_expense_logic.dart';
import '../widgets/category_detail_sheet.dart';
import '../../../core/professional_pdf_generator.dart' show ProfessionalPdfGenerator;

class ExpenditureDetailsPage extends StatefulWidget {
  final AppDatabase db;
  final domain.ExpenditureItem expense;
  final ExpenditureViewModel viewModel;

  const ExpenditureDetailsPage({
    super.key,
    required this.db,
    required this.expense,
    required this.viewModel,
  });

  @override
  State<ExpenditureDetailsPage> createState() => _ExpenditureDetailsPageState();
}

class _ExpenditureDetailsPageState extends State<ExpenditureDetailsPage> {
  bool _loading = true;
  final f = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    await widget.viewModel.loadSubItems(widget.expense.id);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ExpenditureViewModel>.value(
      value: widget.viewModel,
      child: Consumer<ExpenditureViewModel>(
        builder: (context, viewModel, child) {
          if (_loading) {
            return Scaffold(
              appBar: AppBar(
                title: Text('Expense Details', style: AppFonts.poppins(fontWeight: FontWeight.w600)),
              ),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          final isOfficeExpense = widget.expense.categoryType == 'office_expense' || widget.expense.kind == 'office';
          final subItemsTotal = viewModel.subItemsTotal;

          return Scaffold(
            appBar: AppBar(
              title: Text('Expense Details', style: AppFonts.poppins(fontWeight: FontWeight.w600)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.receipt_long),
                  onPressed: () => _generateProfessionalReceipt(viewModel),
                  tooltip: 'Generate Professional Receipt',
                ),
                if (!isOfficeExpense && viewModel.canAdd)
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _showAddSubItemDialog(context, viewModel),
                    tooltip: 'Add Sub-Item',
                  ),
              ],
            ),
            body: Column(
              children: [
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFF4A90E2)]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.expense.category ?? 'Uncategorized', style: AppFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 8),
                      if (widget.expense.description.isNotEmpty && widget.expense.description != (widget.expense.category ?? '')) ...[
                        Text(widget.expense.description, style: AppFonts.poppins(fontSize: 16, color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 12),
                      ],
                      Row(children: [Icon(Icons.calendar_today, color: Colors.white70, size: 16), const SizedBox(width: 8), Text(widget.expense.date, style: AppFonts.poppins(color: Colors.white70, fontSize: 14))]),
                      const SizedBox(height: 16),
                      if (isOfficeExpense) ...[
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('Amount', style: AppFonts.poppins(color: Colors.white70, fontSize: 14)),
                          Text(f.format(widget.expense.amount), style: AppFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        ]),
                      ] else ...[
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Main Amount', style: AppFonts.poppins(color: Colors.white70, fontSize: 12)),
                            Text(f.format(widget.expense.amount), style: AppFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          ]),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text('Sub-Items Total', style: AppFonts.poppins(color: Colors.white70, fontSize: 12)),
                            Text(f.format(subItemsTotal), style: AppFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          ]),
                        ]),
                        const SizedBox(height: 12),
                        Container(height: 1, color: Colors.white30),
                        const SizedBox(height: 12),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('Total Expense', style: AppFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                          Text(f.format(widget.expense.amount + subItemsTotal), style: AppFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        ]),
                      ],
                    ],
                  ),
                ),
                if (viewModel.subItems.isNotEmpty) ...[
                  Expanded(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Expense Breakdown', style: AppFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                              if (!isOfficeExpense && viewModel.canAdd)
                                IconButton(icon: const Icon(Icons.add_circle), onPressed: () => _showAddSubItemDialog(context, viewModel), tooltip: 'Add Sub-Item'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Expense Details', style: AppFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7) ?? Colors.grey.shade700)),
                              const SizedBox(height: 12),
                              _buildCategorySummary(viewModel.subItems),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(child: _buildGroupedCategoryView(viewModel.subItems)),
                      ],
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: isOfficeExpense ? Colors.green.shade50 : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isOfficeExpense ? Colors.green.shade200 : Colors.blue.shade200),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.check_circle, color: isOfficeExpense ? Colors.green.shade600 : Colors.blue.shade600, size: 48),
                                const SizedBox(height: 16),
                                Text('${isOfficeExpense ? 'Office' : 'Project'} Expense Complete', style: AppFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: isOfficeExpense ? Colors.green.shade800 : Colors.blue.shade800)),
                                const SizedBox(height: 8),
                                Text('This expense has been recorded\nwithout sub-item breakdown', style: AppFonts.poppins(fontSize: 14, color: isOfficeExpense ? Colors.green.shade600 : Colors.blue.shade600), textAlign: TextAlign.center),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategorySummary(List<domain.ExpenditureSubItem> subItems) {
    final Map<String, double> categoryTotals = {};
    for (final item in subItems) {
      final category = item.category?.isNotEmpty == true ? item.category! : 'Uncategorized';
      categoryTotals[category] = (categoryTotals[category] ?? 0.0) + item.amount;
    }
    final sortedCategories = categoryTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [const Color(0xFFFF6B35).withOpacity(0.05), const Color(0xFF4A90E2).withOpacity(0.05)]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: sortedCategories.map((entry) {
          final category = entry.key;
          final amount = entry.value;
          final color = _getCategoryColor(category);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3), width: 1)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(category, style: AppFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
                const SizedBox(width: 6),
                Text(':', style: AppFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                const SizedBox(width: 6),
                Text(f.format(amount), style: AppFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    final categoryColors = {
      'Civil work material': Colors.brown,
      'Sanitary material': Colors.blue,
      'Electric material': Colors.yellow,
      'Steel work material': Colors.grey,
      'Wood work material': Colors.orange,
      'Labor': Colors.green,
      'Transport': Colors.purple,
      'Utility bill': Colors.cyan,
      'Rental tools': Colors.indigo,
      'Other': Colors.red,
      'Uncategorized': Colors.grey,
    };
    return categoryColors[category] ?? Colors.grey;
  }

  void _showAddSubItemDialog(BuildContext context, ExpenditureViewModel viewModel) {
    const List<String> categoryItems = [
      "Civil work material", "Sanitary material", "Electric material",
      "Steel work material", "Wood work material", "Labor",
      "Transport", "Utility bill", "Rental tools", "Other"
    ];
    String? selectedCategory;
    final customCategoryController = TextEditingController();
    bool showCustomCategory = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              insetPadding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.5, minWidth: 450, maxHeight: MediaQuery.of(context).size.height * 0.8),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFFF6B35).withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.add_circle_outline, color: Color(0xFFFF6B35), size: 24)),
                          const SizedBox(width: 16),
                          Expanded(child: Text('Add Sub-Item', style: AppFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold))),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(dialogContext)),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Description', style: AppFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 12),
                              TextField(
                                controller: viewModel.itemDescriptionController,
                                decoration: InputDecoration(hintText: 'Enter description...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50),
                              ),
                              const SizedBox(height: 24),
                              Text('Amount', style: AppFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 12),
                              TextField(
                                controller: viewModel.itemAmountController,
                                decoration: InputDecoration(hintText: 'Enter amount...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50),
                                keyboardType: TextInputType.number,
                              ),
                              const SizedBox(height: 24),
                              Text('Category', style: AppFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: selectedCategory,
                                decoration: InputDecoration(hintText: 'Select category...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50),
                                items: categoryItems.map((String category) {
                                  return DropdownMenuItem<String>(value: category, child: Text(category, style: AppFonts.poppins(fontWeight: FontWeight.w500)));
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    selectedCategory = newValue;
                                    showCustomCategory = (newValue == "Other");
                                    if (!showCustomCategory) customCategoryController.clear();
                                  });
                                },
                              ),
                              if (showCustomCategory) ...[
                                const SizedBox(height: 24),
                                Text('Custom Category', style: AppFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 12),
                                TextField(controller: customCategoryController, decoration: InputDecoration(hintText: 'Specify custom category...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50)),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('Cancel')),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () async {
                              String finalCategory = '';
                              if (selectedCategory != null) {
                                if (selectedCategory == "Other" && customCategoryController.text.isNotEmpty) {
                                  finalCategory = customCategoryController.text.trim();
                                } else if (selectedCategory != "Other") {
                                  finalCategory = selectedCategory!;
                                }
                              }
                              final success = await viewModel.saveSubItemWithCategory(widget.expense.id, category: finalCategory.isEmpty ? null : finalCategory);
                              if (success && dialogContext.mounted) Navigator.pop(dialogContext);
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B35), foregroundColor: Colors.white),
                            child: Text('Save Item', style: AppFonts.poppins(fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleDeleteSubItem(BuildContext context, ExpenditureViewModel viewModel, dynamic item) async {
    final confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Sub-Item?"),
        content: const Text("Are you sure you want to delete this sub-item?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await viewModel.deleteSubItem(item.id);
    }
  }

  Future<void> _generateProfessionalReceipt(ExpenditureViewModel viewModel) async {
    final subItemsTotal = viewModel.subItemsTotal;
    final keyValues = <MapEntry<String, String>>[
      MapEntry('Expense ID', widget.expense.id),
      MapEntry('Category', widget.expense.category ?? widget.expense.description),
      MapEntry('Date', widget.expense.date),
      MapEntry('Type', widget.expense.categoryType ?? 'N/A'),
      MapEntry('Main Amount', f.format(widget.expense.amount)),
      MapEntry('Sub-Items Count', '${viewModel.subItems.length}'),
      MapEntry('Sub-Items Total', f.format(subItemsTotal)),
      MapEntry('Total Expense', f.format(widget.expense.amount + subItemsTotal)),
      MapEntry('Generated By', viewModel.user?['username']?.toString() ?? 'N/A'),
    ];
    final gridRows = viewModel.subItems.map((subItem) => {
      'Description': subItem.description,
      'Amount': f.format(subItem.amount),
      'Date Added': subItem.createdAt ?? 'N/A',
    }).toList();
    await ProfessionalPdfGenerator.generateReceipt(
      context: context,
      db: widget.db,
      module: 'Expenditure',
      title: 'Expense Details Receipt',
      entityId: widget.expense.id,
      keyValues: keyValues,
      gridRows: gridRows.cast<Map<String, String>>(),
    );
  }

  Widget _buildGroupedCategoryView(List<domain.ExpenditureSubItem> subItems) {
    if (subItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No Sub-Items Found', style: AppFonts.poppins(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
            if (widget.viewModel.canAdd) Text('Tap + to add breakdown items', style: AppFonts.poppins(fontSize: 14, color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    final groupedData = GroupedExpenseLogic.getGroupedExpenseData(subItems);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: groupedData.sortedCategories.length,
      itemBuilder: (context, index) {
        final category = groupedData.sortedCategories[index];
        final categoryTotal = groupedData.categoryTotals[category] ?? 0.0;
        final categoryExpenses = groupedData.groupedExpenses[category] ?? [];
        final categoryColor = _getCategoryColor(category);

        return InkWell(
          onTap: () => showCategoryDetailSheet(
            context: context,
            categoryName: category,
            expenses: categoryExpenses,
            categoryTotal: categoryTotal,
            onDeleteItem: widget.viewModel.canAdd ? (expense) => _handleDeleteSubItem(context, widget.viewModel, expense) : null,
          ),
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(colors: [categoryColor.withOpacity(0.05), categoryColor.withOpacity(0.02)]),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(gradient: LinearGradient(colors: [categoryColor.withOpacity(0.2), categoryColor.withOpacity(0.1)]), borderRadius: BorderRadius.circular(12)),
                          child: Icon(_getCategoryIcon(category), color: categoryColor, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(category, style: AppFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('${categoryExpenses.length} item${categoryExpenses.length == 1 ? '' : 's'}', style: AppFonts.poppins(fontSize: 14, color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(f.format(categoryTotal), style: AppFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: categoryColor)),
                            const SizedBox(height: 4),
                            Icon(Icons.arrow_forward_ios, color: categoryColor.withOpacity(0.6), size: 16),
                          ],
                        ),
                      ],
                    ),
                    if (categoryExpenses.length > 2) ...[
                      const SizedBox(height: 16),
                      Container(height: 1, color: Colors.grey.shade200),
                      const SizedBox(height: 12),
                      ...categoryExpenses.take(2).map((expense) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(width: 6, height: 6, decoration: BoxDecoration(color: categoryColor.withOpacity(0.4), shape: BoxShape.circle)),
                            const SizedBox(width: 12),
                            Expanded(child: Text(expense.description, style: AppFonts.poppins(fontSize: 13, color: Colors.grey.shade700), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            Text(f.format(expense.amount), style: AppFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                          ],
                        ),
                      )),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const SizedBox(width: 18),
                            Text('+${categoryExpenses.length - 2} more items', style: AppFonts.poppins(fontSize: 12, color: categoryColor, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _getCategoryIcon(String category) {
    final categoryIcons = {
      'Civil work material': Icons.construction,
      'Sanitary material': Icons.bathtub,
      'Electric material': Icons.electrical_services,
      'Steel work material': Icons.hardware,
      'Wood work material': Icons.carpenter,
      'Labor': Icons.people,
      'Transport': Icons.local_shipping,
      'Utility bill': Icons.receipt_long,
      'Rental tools': Icons.build,
      'Other': Icons.category,
      'Uncategorized': Icons.help_outline,
    };
    return categoryIcons[category] ?? Icons.category;
  }
}