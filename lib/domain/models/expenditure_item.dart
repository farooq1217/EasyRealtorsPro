import 'package:equatable/equatable.dart';

class ExpenditureItem extends Equatable {
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
  final String? categoryType; // 'office' | 'project'
  final bool isActive;
  final bool isSynced;
  final String? createdAt;
  final String? updatedAt;

  const ExpenditureItem({
    required this.id,
    required this.date,
    required this.description,
    required this.amount,
    this.category,
    this.companyId,
    this.createdBy,
    this.kind,
    this.projectId,
    this.categoryId,
    this.officeMonth,
    this.categoryType,
    this.isActive = true,
    this.isSynced = true,
    this.createdAt,
    this.updatedAt,
  });

  ExpenditureItem copyWith({
    String? id,
    String? date,
    String? description,
    double? amount,
    String? category,
    String? companyId,
    String? createdBy,
    String? kind,
    String? projectId,
    String? categoryId,
    String? officeMonth,
    String? categoryType,
    bool? isActive,
    bool? isSynced,
    String? createdAt,
    String? updatedAt,
  }) {
    return ExpenditureItem(
      id: id ?? this.id,
      date: date ?? this.date,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      companyId: companyId ?? this.companyId,
      createdBy: createdBy ?? this.createdBy,
      kind: kind ?? this.kind,
      projectId: projectId ?? this.projectId,
      categoryId: categoryId ?? this.categoryId,
      officeMonth: officeMonth ?? this.officeMonth,
      categoryType: categoryType ?? this.categoryType,
      isActive: isActive ?? this.isActive,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'description': description,
      'amount': amount,
      'category': category,
      'company_id': companyId,
      'created_by': createdBy,
      'kind': kind,
      'project_id': projectId,
      'category_id': categoryId,
      'office_month': officeMonth,
      'category_type': categoryType,
      'is_active': isActive ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory ExpenditureItem.fromMap(Map<String, dynamic> map) {
    final rawAmount = map['amount'];
    double parsedAmount;
    if (rawAmount is num) {
      parsedAmount = rawAmount.toDouble();
    } else {
      parsedAmount = double.tryParse(rawAmount?.toString() ?? '') ?? 0;
    }

    return ExpenditureItem(
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
      categoryType: (map['categoryType'] ?? map['category_type'])?.toString(),
      isActive: (map['is_active'] is int ? map['is_active'] == 1 : map['is_active'] == true) ?? true,
      isSynced: (map['is_synced'] is int ? map['is_synced'] == 1 : map['is_synced'] == true) ?? true,
      createdAt: map['created_at']?.toString(),
      updatedAt: map['updated_at']?.toString(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        date,
        description,
        amount,
        category,
        companyId,
        createdBy,
        kind,
        projectId,
        categoryId,
        officeMonth,
        categoryType,
        isActive,
        isSynced,
        createdAt,
        updatedAt,
      ];
}

class ExpenditureSubItem extends Equatable {
  final String id;
  final String parentId;
  final String description;
  final double amount;
  final String? companyId;
  final String? createdBy;
  final bool isActive;
  final bool isSynced;
  final String? createdAt;
  final String? updatedAt;

  const ExpenditureSubItem({
    required this.id,
    required this.parentId,
    required this.description,
    required this.amount,
    this.companyId,
    this.createdBy,
    this.isActive = true,
    this.isSynced = true,
    this.createdAt,
    this.updatedAt,
  });

  ExpenditureSubItem copyWith({
    String? id,
    String? parentId,
    String? description,
    double? amount,
    String? companyId,
    String? createdBy,
    bool? isActive,
    bool? isSynced,
    String? createdAt,
    String? updatedAt,
  }) {
    return ExpenditureSubItem(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      companyId: companyId ?? this.companyId,
      createdBy: createdBy ?? this.createdBy,
      isActive: isActive ?? this.isActive,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'parent_id': parentId,
      'description': description,
      'amount': amount,
      'company_id': companyId,
      'created_by': createdBy,
      'is_active': isActive ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory ExpenditureSubItem.fromMap(Map<String, dynamic> map) {
    final rawAmount = map['amount'];
    double parsedAmount;
    if (rawAmount is num) {
      parsedAmount = rawAmount.toDouble();
    } else {
      parsedAmount = double.tryParse(rawAmount?.toString() ?? '') ?? 0;
    }

    return ExpenditureSubItem(
      id: (map['id'] ?? '').toString(),
      parentId: (map['parent_id'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      amount: parsedAmount,
      companyId: (map['company_id'])?.toString(),
      createdBy: (map['created_by'])?.toString(),
      isActive: (map['is_active'] is int ? map['is_active'] == 1 : map['is_active'] == true) ?? true,
      isSynced: (map['is_synced'] is int ? map['is_synced'] == 1 : map['is_synced'] == true) ?? true,
      createdAt: map['created_at']?.toString(),
      updatedAt: map['updated_at']?.toString(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        parentId,
        description,
        amount,
        companyId,
        createdBy,
        isActive,
        isSynced,
        createdAt,
        updatedAt,
      ];
}
