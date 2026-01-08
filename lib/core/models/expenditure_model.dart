class ExpenditureModel {
  final String id;
  final String date;
  final String description;
  final double amount;
  final String? category;
  final String? companyId;
  final String? createdBy;
  final String? kind; // 'office' | 'project'
  final String? projectId;
  final String? categoryId;
  final String? officeMonth; // yyyy-MM

  const ExpenditureModel({
    required this.id,
    required this.date,
    required this.description,
    required this.amount,
    this.category,
    required this.companyId,
    this.createdBy,
    this.kind,
    this.projectId,
    this.categoryId,
    this.officeMonth,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'description': description,
      'amount': amount,
      'category': category,
      'companyId': companyId,
      'createdBy': createdBy,
      'kind': kind,
      'projectId': projectId,
      'categoryId': categoryId,
      'officeMonth': officeMonth,
    };
  }

  factory ExpenditureModel.fromMap(Map<String, dynamic> map) {
    final rawAmount = map['amount'];
    double parsedAmount;
    if (rawAmount is num) {
      parsedAmount = rawAmount.toDouble();
    } else {
      parsedAmount = double.tryParse(rawAmount?.toString() ?? '') ?? 0;
    }

    return ExpenditureModel(
      id: (map['id'] ?? '').toString(),
      date: (map['date'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      amount: parsedAmount,
      category: (map['category'] ?? map['expense_category'] ?? map['expenseCategory'])?.toString(),
      companyId: (map['companyId'] ?? map['company_id'])?.toString(),
      createdBy: (map['createdBy'] ?? map['created_by'])?.toString(),
      kind: (map['kind'] ?? map['type'])?.toString(),
      projectId: (map['projectId'] ?? map['project_id'])?.toString(),
      categoryId: (map['categoryId'] ?? map['category_id'])?.toString(),
      officeMonth: (map['officeMonth'] ?? map['office_month'])?.toString(),
    );
  }
}
