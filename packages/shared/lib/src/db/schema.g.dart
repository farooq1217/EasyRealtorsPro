// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schema.dart';

// ignore_for_file: type=lint
class $CompaniesTable extends Companies
    with TableInfo<$CompaniesTable, Company> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CompaniesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _metadataMeta =
      const VerificationMeta('metadata');
  @override
  late final GeneratedColumn<String> metadata = GeneratedColumn<String>(
      'metadata', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _maxUserLimitMeta =
      const VerificationMeta('maxUserLimit');
  @override
  late final GeneratedColumn<int> maxUserLimit = GeneratedColumn<int>(
      'max_user_limit', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(5));
  static const VerificationMeta _subscriptionTierMeta =
      const VerificationMeta('subscriptionTier');
  @override
  late final GeneratedColumn<String> subscriptionTier = GeneratedColumn<String>(
      'subscription_tier', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('Starter'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
      'created_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        status,
        metadata,
        maxUserLimit,
        subscriptionTier,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'companies';
  @override
  VerificationContext validateIntegrity(Insertable<Company> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('metadata')) {
      context.handle(_metadataMeta,
          metadata.isAcceptableOrUnknown(data['metadata']!, _metadataMeta));
    }
    if (data.containsKey('max_user_limit')) {
      context.handle(
          _maxUserLimitMeta,
          maxUserLimit.isAcceptableOrUnknown(
              data['max_user_limit']!, _maxUserLimitMeta));
    }
    if (data.containsKey('subscription_tier')) {
      context.handle(
          _subscriptionTierMeta,
          subscriptionTier.isAcceptableOrUnknown(
              data['subscription_tier']!, _subscriptionTierMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Company map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Company(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      metadata: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}metadata']),
      maxUserLimit: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}max_user_limit'])!,
      subscriptionTier: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}subscription_tier'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $CompaniesTable createAlias(String alias) {
    return $CompaniesTable(attachedDatabase, alias);
  }
}

class Company extends DataClass implements Insertable<Company> {
  final String id;
  final String name;
  final String status;
  final String? metadata;
  final int maxUserLimit;
  final String subscriptionTier;
  final String createdAt;
  final String updatedAt;
  const Company(
      {required this.id,
      required this.name,
      required this.status,
      this.metadata,
      required this.maxUserLimit,
      required this.subscriptionTier,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || metadata != null) {
      map['metadata'] = Variable<String>(metadata);
    }
    map['max_user_limit'] = Variable<int>(maxUserLimit);
    map['subscription_tier'] = Variable<String>(subscriptionTier);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  CompaniesCompanion toCompanion(bool nullToAbsent) {
    return CompaniesCompanion(
      id: Value(id),
      name: Value(name),
      status: Value(status),
      metadata: metadata == null && nullToAbsent
          ? const Value.absent()
          : Value(metadata),
      maxUserLimit: Value(maxUserLimit),
      subscriptionTier: Value(subscriptionTier),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Company.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Company(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      status: serializer.fromJson<String>(json['status']),
      metadata: serializer.fromJson<String?>(json['metadata']),
      maxUserLimit: serializer.fromJson<int>(json['maxUserLimit']),
      subscriptionTier: serializer.fromJson<String>(json['subscriptionTier']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'status': serializer.toJson<String>(status),
      'metadata': serializer.toJson<String?>(metadata),
      'maxUserLimit': serializer.toJson<int>(maxUserLimit),
      'subscriptionTier': serializer.toJson<String>(subscriptionTier),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  Company copyWith(
          {String? id,
          String? name,
          String? status,
          Value<String?> metadata = const Value.absent(),
          int? maxUserLimit,
          String? subscriptionTier,
          String? createdAt,
          String? updatedAt}) =>
      Company(
        id: id ?? this.id,
        name: name ?? this.name,
        status: status ?? this.status,
        metadata: metadata.present ? metadata.value : this.metadata,
        maxUserLimit: maxUserLimit ?? this.maxUserLimit,
        subscriptionTier: subscriptionTier ?? this.subscriptionTier,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Company copyWithCompanion(CompaniesCompanion data) {
    return Company(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      status: data.status.present ? data.status.value : this.status,
      metadata: data.metadata.present ? data.metadata.value : this.metadata,
      maxUserLimit: data.maxUserLimit.present
          ? data.maxUserLimit.value
          : this.maxUserLimit,
      subscriptionTier: data.subscriptionTier.present
          ? data.subscriptionTier.value
          : this.subscriptionTier,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Company(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('status: $status, ')
          ..write('metadata: $metadata, ')
          ..write('maxUserLimit: $maxUserLimit, ')
          ..write('subscriptionTier: $subscriptionTier, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, status, metadata, maxUserLimit,
      subscriptionTier, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Company &&
          other.id == this.id &&
          other.name == this.name &&
          other.status == this.status &&
          other.metadata == this.metadata &&
          other.maxUserLimit == this.maxUserLimit &&
          other.subscriptionTier == this.subscriptionTier &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CompaniesCompanion extends UpdateCompanion<Company> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> status;
  final Value<String?> metadata;
  final Value<int> maxUserLimit;
  final Value<String> subscriptionTier;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const CompaniesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.status = const Value.absent(),
    this.metadata = const Value.absent(),
    this.maxUserLimit = const Value.absent(),
    this.subscriptionTier = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CompaniesCompanion.insert({
    required String id,
    required String name,
    required String status,
    this.metadata = const Value.absent(),
    this.maxUserLimit = const Value.absent(),
    this.subscriptionTier = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        status = Value(status),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<Company> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? status,
    Expression<String>? metadata,
    Expression<int>? maxUserLimit,
    Expression<String>? subscriptionTier,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (status != null) 'status': status,
      if (metadata != null) 'metadata': metadata,
      if (maxUserLimit != null) 'max_user_limit': maxUserLimit,
      if (subscriptionTier != null) 'subscription_tier': subscriptionTier,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CompaniesCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? status,
      Value<String?>? metadata,
      Value<int>? maxUserLimit,
      Value<String>? subscriptionTier,
      Value<String>? createdAt,
      Value<String>? updatedAt,
      Value<int>? rowid}) {
    return CompaniesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      metadata: metadata ?? this.metadata,
      maxUserLimit: maxUserLimit ?? this.maxUserLimit,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (metadata.present) {
      map['metadata'] = Variable<String>(metadata.value);
    }
    if (maxUserLimit.present) {
      map['max_user_limit'] = Variable<int>(maxUserLimit.value);
    }
    if (subscriptionTier.present) {
      map['subscription_tier'] = Variable<String>(subscriptionTier.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CompaniesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('status: $status, ')
          ..write('metadata: $metadata, ')
          ..write('maxUserLimit: $maxUserLimit, ')
          ..write('subscriptionTier: $subscriptionTier, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UsersTable extends Users with TableInfo<$UsersTable, User> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _usernameMeta =
      const VerificationMeta('username');
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
      'username', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _passwordHashMeta =
      const VerificationMeta('passwordHash');
  @override
  late final GeneratedColumn<String> passwordHash = GeneratedColumn<String>(
      'password_hash', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _saltMeta = const VerificationMeta('salt');
  @override
  late final GeneratedColumn<String> salt = GeneratedColumn<String>(
      'salt', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _iterationsMeta =
      const VerificationMeta('iterations');
  @override
  late final GeneratedColumn<int> iterations = GeneratedColumn<int>(
      'iterations', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
      'email', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _contactNoMeta =
      const VerificationMeta('contactNo');
  @override
  late final GeneratedColumn<String> contactNo = GeneratedColumn<String>(
      'contact_no', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _permissionsMeta =
      const VerificationMeta('permissions');
  @override
  late final GeneratedColumn<String> permissions = GeneratedColumn<String>(
      'permissions', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _companyIdMeta =
      const VerificationMeta('companyId');
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
      'company_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES companies (id)'));
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isFirstLoginMeta =
      const VerificationMeta('isFirstLogin');
  @override
  late final GeneratedColumn<bool> isFirstLogin = GeneratedColumn<bool>(
      'is_first_login', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_first_login" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _isActiveMeta =
      const VerificationMeta('isActive');
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
      'is_active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_active" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
      'created_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        username,
        passwordHash,
        salt,
        iterations,
        userId,
        name,
        email,
        contactNo,
        permissions,
        companyId,
        status,
        isFirstLogin,
        isActive,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'users';
  @override
  VerificationContext validateIntegrity(Insertable<User> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('username')) {
      context.handle(_usernameMeta,
          username.isAcceptableOrUnknown(data['username']!, _usernameMeta));
    } else if (isInserting) {
      context.missing(_usernameMeta);
    }
    if (data.containsKey('password_hash')) {
      context.handle(
          _passwordHashMeta,
          passwordHash.isAcceptableOrUnknown(
              data['password_hash']!, _passwordHashMeta));
    }
    if (data.containsKey('salt')) {
      context.handle(
          _saltMeta, salt.isAcceptableOrUnknown(data['salt']!, _saltMeta));
    }
    if (data.containsKey('iterations')) {
      context.handle(
          _iterationsMeta,
          iterations.isAcceptableOrUnknown(
              data['iterations']!, _iterationsMeta));
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    }
    if (data.containsKey('email')) {
      context.handle(
          _emailMeta, email.isAcceptableOrUnknown(data['email']!, _emailMeta));
    }
    if (data.containsKey('contact_no')) {
      context.handle(_contactNoMeta,
          contactNo.isAcceptableOrUnknown(data['contact_no']!, _contactNoMeta));
    }
    if (data.containsKey('permissions')) {
      context.handle(
          _permissionsMeta,
          permissions.isAcceptableOrUnknown(
              data['permissions']!, _permissionsMeta));
    }
    if (data.containsKey('company_id')) {
      context.handle(_companyIdMeta,
          companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('is_first_login')) {
      context.handle(
          _isFirstLoginMeta,
          isFirstLogin.isAcceptableOrUnknown(
              data['is_first_login']!, _isFirstLoginMeta));
    }
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  User map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return User(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      username: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}username'])!,
      passwordHash: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}password_hash']),
      salt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}salt']),
      iterations: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}iterations']),
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id']),
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name']),
      email: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}email']),
      contactNo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}contact_no']),
      permissions: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}permissions']),
      companyId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}company_id']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status']),
      isFirstLogin: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_first_login'])!,
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}created_at']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $UsersTable createAlias(String alias) {
    return $UsersTable(attachedDatabase, alias);
  }
}

class User extends DataClass implements Insertable<User> {
  final String id;
  final String username;
  final String? passwordHash;
  final String? salt;
  final int? iterations;
  final String? userId;
  final String? name;
  final String? email;
  final String? contactNo;
  final String? permissions;
  final String? companyId;
  final String? status;
  final bool isFirstLogin;
  final bool isActive;
  final String? createdAt;
  final String updatedAt;
  const User(
      {required this.id,
      required this.username,
      this.passwordHash,
      this.salt,
      this.iterations,
      this.userId,
      this.name,
      this.email,
      this.contactNo,
      this.permissions,
      this.companyId,
      this.status,
      required this.isFirstLogin,
      required this.isActive,
      this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['username'] = Variable<String>(username);
    if (!nullToAbsent || passwordHash != null) {
      map['password_hash'] = Variable<String>(passwordHash);
    }
    if (!nullToAbsent || salt != null) {
      map['salt'] = Variable<String>(salt);
    }
    if (!nullToAbsent || iterations != null) {
      map['iterations'] = Variable<int>(iterations);
    }
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || contactNo != null) {
      map['contact_no'] = Variable<String>(contactNo);
    }
    if (!nullToAbsent || permissions != null) {
      map['permissions'] = Variable<String>(permissions);
    }
    if (!nullToAbsent || companyId != null) {
      map['company_id'] = Variable<String>(companyId);
    }
    if (!nullToAbsent || status != null) {
      map['status'] = Variable<String>(status);
    }
    map['is_first_login'] = Variable<bool>(isFirstLogin);
    map['is_active'] = Variable<bool>(isActive);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  UsersCompanion toCompanion(bool nullToAbsent) {
    return UsersCompanion(
      id: Value(id),
      username: Value(username),
      passwordHash: passwordHash == null && nullToAbsent
          ? const Value.absent()
          : Value(passwordHash),
      salt: salt == null && nullToAbsent ? const Value.absent() : Value(salt),
      iterations: iterations == null && nullToAbsent
          ? const Value.absent()
          : Value(iterations),
      userId:
          userId == null && nullToAbsent ? const Value.absent() : Value(userId),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      email:
          email == null && nullToAbsent ? const Value.absent() : Value(email),
      contactNo: contactNo == null && nullToAbsent
          ? const Value.absent()
          : Value(contactNo),
      permissions: permissions == null && nullToAbsent
          ? const Value.absent()
          : Value(permissions),
      companyId: companyId == null && nullToAbsent
          ? const Value.absent()
          : Value(companyId),
      status:
          status == null && nullToAbsent ? const Value.absent() : Value(status),
      isFirstLogin: Value(isFirstLogin),
      isActive: Value(isActive),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory User.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return User(
      id: serializer.fromJson<String>(json['id']),
      username: serializer.fromJson<String>(json['username']),
      passwordHash: serializer.fromJson<String?>(json['passwordHash']),
      salt: serializer.fromJson<String?>(json['salt']),
      iterations: serializer.fromJson<int?>(json['iterations']),
      userId: serializer.fromJson<String?>(json['userId']),
      name: serializer.fromJson<String?>(json['name']),
      email: serializer.fromJson<String?>(json['email']),
      contactNo: serializer.fromJson<String?>(json['contactNo']),
      permissions: serializer.fromJson<String?>(json['permissions']),
      companyId: serializer.fromJson<String?>(json['companyId']),
      status: serializer.fromJson<String?>(json['status']),
      isFirstLogin: serializer.fromJson<bool>(json['isFirstLogin']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<String?>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'username': serializer.toJson<String>(username),
      'passwordHash': serializer.toJson<String?>(passwordHash),
      'salt': serializer.toJson<String?>(salt),
      'iterations': serializer.toJson<int?>(iterations),
      'userId': serializer.toJson<String?>(userId),
      'name': serializer.toJson<String?>(name),
      'email': serializer.toJson<String?>(email),
      'contactNo': serializer.toJson<String?>(contactNo),
      'permissions': serializer.toJson<String?>(permissions),
      'companyId': serializer.toJson<String?>(companyId),
      'status': serializer.toJson<String?>(status),
      'isFirstLogin': serializer.toJson<bool>(isFirstLogin),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<String?>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  User copyWith(
          {String? id,
          String? username,
          Value<String?> passwordHash = const Value.absent(),
          Value<String?> salt = const Value.absent(),
          Value<int?> iterations = const Value.absent(),
          Value<String?> userId = const Value.absent(),
          Value<String?> name = const Value.absent(),
          Value<String?> email = const Value.absent(),
          Value<String?> contactNo = const Value.absent(),
          Value<String?> permissions = const Value.absent(),
          Value<String?> companyId = const Value.absent(),
          Value<String?> status = const Value.absent(),
          bool? isFirstLogin,
          bool? isActive,
          Value<String?> createdAt = const Value.absent(),
          String? updatedAt}) =>
      User(
        id: id ?? this.id,
        username: username ?? this.username,
        passwordHash:
            passwordHash.present ? passwordHash.value : this.passwordHash,
        salt: salt.present ? salt.value : this.salt,
        iterations: iterations.present ? iterations.value : this.iterations,
        userId: userId.present ? userId.value : this.userId,
        name: name.present ? name.value : this.name,
        email: email.present ? email.value : this.email,
        contactNo: contactNo.present ? contactNo.value : this.contactNo,
        permissions: permissions.present ? permissions.value : this.permissions,
        companyId: companyId.present ? companyId.value : this.companyId,
        status: status.present ? status.value : this.status,
        isFirstLogin: isFirstLogin ?? this.isFirstLogin,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  User copyWithCompanion(UsersCompanion data) {
    return User(
      id: data.id.present ? data.id.value : this.id,
      username: data.username.present ? data.username.value : this.username,
      passwordHash: data.passwordHash.present
          ? data.passwordHash.value
          : this.passwordHash,
      salt: data.salt.present ? data.salt.value : this.salt,
      iterations:
          data.iterations.present ? data.iterations.value : this.iterations,
      userId: data.userId.present ? data.userId.value : this.userId,
      name: data.name.present ? data.name.value : this.name,
      email: data.email.present ? data.email.value : this.email,
      contactNo: data.contactNo.present ? data.contactNo.value : this.contactNo,
      permissions:
          data.permissions.present ? data.permissions.value : this.permissions,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      status: data.status.present ? data.status.value : this.status,
      isFirstLogin: data.isFirstLogin.present
          ? data.isFirstLogin.value
          : this.isFirstLogin,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('User(')
          ..write('id: $id, ')
          ..write('username: $username, ')
          ..write('passwordHash: $passwordHash, ')
          ..write('salt: $salt, ')
          ..write('iterations: $iterations, ')
          ..write('userId: $userId, ')
          ..write('name: $name, ')
          ..write('email: $email, ')
          ..write('contactNo: $contactNo, ')
          ..write('permissions: $permissions, ')
          ..write('companyId: $companyId, ')
          ..write('status: $status, ')
          ..write('isFirstLogin: $isFirstLogin, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      username,
      passwordHash,
      salt,
      iterations,
      userId,
      name,
      email,
      contactNo,
      permissions,
      companyId,
      status,
      isFirstLogin,
      isActive,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is User &&
          other.id == this.id &&
          other.username == this.username &&
          other.passwordHash == this.passwordHash &&
          other.salt == this.salt &&
          other.iterations == this.iterations &&
          other.userId == this.userId &&
          other.name == this.name &&
          other.email == this.email &&
          other.contactNo == this.contactNo &&
          other.permissions == this.permissions &&
          other.companyId == this.companyId &&
          other.status == this.status &&
          other.isFirstLogin == this.isFirstLogin &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class UsersCompanion extends UpdateCompanion<User> {
  final Value<String> id;
  final Value<String> username;
  final Value<String?> passwordHash;
  final Value<String?> salt;
  final Value<int?> iterations;
  final Value<String?> userId;
  final Value<String?> name;
  final Value<String?> email;
  final Value<String?> contactNo;
  final Value<String?> permissions;
  final Value<String?> companyId;
  final Value<String?> status;
  final Value<bool> isFirstLogin;
  final Value<bool> isActive;
  final Value<String?> createdAt;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const UsersCompanion({
    this.id = const Value.absent(),
    this.username = const Value.absent(),
    this.passwordHash = const Value.absent(),
    this.salt = const Value.absent(),
    this.iterations = const Value.absent(),
    this.userId = const Value.absent(),
    this.name = const Value.absent(),
    this.email = const Value.absent(),
    this.contactNo = const Value.absent(),
    this.permissions = const Value.absent(),
    this.companyId = const Value.absent(),
    this.status = const Value.absent(),
    this.isFirstLogin = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UsersCompanion.insert({
    required String id,
    required String username,
    this.passwordHash = const Value.absent(),
    this.salt = const Value.absent(),
    this.iterations = const Value.absent(),
    this.userId = const Value.absent(),
    this.name = const Value.absent(),
    this.email = const Value.absent(),
    this.contactNo = const Value.absent(),
    this.permissions = const Value.absent(),
    this.companyId = const Value.absent(),
    this.status = const Value.absent(),
    this.isFirstLogin = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    required String updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        username = Value(username),
        updatedAt = Value(updatedAt);
  static Insertable<User> custom({
    Expression<String>? id,
    Expression<String>? username,
    Expression<String>? passwordHash,
    Expression<String>? salt,
    Expression<int>? iterations,
    Expression<String>? userId,
    Expression<String>? name,
    Expression<String>? email,
    Expression<String>? contactNo,
    Expression<String>? permissions,
    Expression<String>? companyId,
    Expression<String>? status,
    Expression<bool>? isFirstLogin,
    Expression<bool>? isActive,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (username != null) 'username': username,
      if (passwordHash != null) 'password_hash': passwordHash,
      if (salt != null) 'salt': salt,
      if (iterations != null) 'iterations': iterations,
      if (userId != null) 'user_id': userId,
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (contactNo != null) 'contact_no': contactNo,
      if (permissions != null) 'permissions': permissions,
      if (companyId != null) 'company_id': companyId,
      if (status != null) 'status': status,
      if (isFirstLogin != null) 'is_first_login': isFirstLogin,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UsersCompanion copyWith(
      {Value<String>? id,
      Value<String>? username,
      Value<String?>? passwordHash,
      Value<String?>? salt,
      Value<int?>? iterations,
      Value<String?>? userId,
      Value<String?>? name,
      Value<String?>? email,
      Value<String?>? contactNo,
      Value<String?>? permissions,
      Value<String?>? companyId,
      Value<String?>? status,
      Value<bool>? isFirstLogin,
      Value<bool>? isActive,
      Value<String?>? createdAt,
      Value<String>? updatedAt,
      Value<int>? rowid}) {
    return UsersCompanion(
      id: id ?? this.id,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      salt: salt ?? this.salt,
      iterations: iterations ?? this.iterations,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      contactNo: contactNo ?? this.contactNo,
      permissions: permissions ?? this.permissions,
      companyId: companyId ?? this.companyId,
      status: status ?? this.status,
      isFirstLogin: isFirstLogin ?? this.isFirstLogin,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (passwordHash.present) {
      map['password_hash'] = Variable<String>(passwordHash.value);
    }
    if (salt.present) {
      map['salt'] = Variable<String>(salt.value);
    }
    if (iterations.present) {
      map['iterations'] = Variable<int>(iterations.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (contactNo.present) {
      map['contact_no'] = Variable<String>(contactNo.value);
    }
    if (permissions.present) {
      map['permissions'] = Variable<String>(permissions.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (isFirstLogin.present) {
      map['is_first_login'] = Variable<bool>(isFirstLogin.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsersCompanion(')
          ..write('id: $id, ')
          ..write('username: $username, ')
          ..write('passwordHash: $passwordHash, ')
          ..write('salt: $salt, ')
          ..write('iterations: $iterations, ')
          ..write('userId: $userId, ')
          ..write('name: $name, ')
          ..write('email: $email, ')
          ..write('contactNo: $contactNo, ')
          ..write('permissions: $permissions, ')
          ..write('companyId: $companyId, ')
          ..write('status: $status, ')
          ..write('isFirstLogin: $isFirstLogin, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SocietiesTable extends Societies
    with TableInfo<$SocietiesTable, Society> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SocietiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _companyIdMeta =
      const VerificationMeta('companyId');
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
      'company_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _metadataMeta =
      const VerificationMeta('metadata');
  @override
  late final GeneratedColumn<String> metadata = GeneratedColumn<String>(
      'metadata', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isActiveMeta =
      const VerificationMeta('isActive');
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
      'is_active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_active" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, companyId, metadata, isActive, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'societies';
  @override
  VerificationContext validateIntegrity(Insertable<Society> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(_companyIdMeta,
          companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta));
    }
    if (data.containsKey('metadata')) {
      context.handle(_metadataMeta,
          metadata.isAcceptableOrUnknown(data['metadata']!, _metadataMeta));
    }
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Society map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Society(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      companyId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}company_id']),
      metadata: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}metadata']),
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $SocietiesTable createAlias(String alias) {
    return $SocietiesTable(attachedDatabase, alias);
  }
}

class Society extends DataClass implements Insertable<Society> {
  final String id;
  final String name;
  final String? companyId;
  final String? metadata;
  final bool isActive;
  final String updatedAt;
  const Society(
      {required this.id,
      required this.name,
      this.companyId,
      this.metadata,
      required this.isActive,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || companyId != null) {
      map['company_id'] = Variable<String>(companyId);
    }
    if (!nullToAbsent || metadata != null) {
      map['metadata'] = Variable<String>(metadata);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  SocietiesCompanion toCompanion(bool nullToAbsent) {
    return SocietiesCompanion(
      id: Value(id),
      name: Value(name),
      companyId: companyId == null && nullToAbsent
          ? const Value.absent()
          : Value(companyId),
      metadata: metadata == null && nullToAbsent
          ? const Value.absent()
          : Value(metadata),
      isActive: Value(isActive),
      updatedAt: Value(updatedAt),
    );
  }

  factory Society.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Society(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      companyId: serializer.fromJson<String?>(json['companyId']),
      metadata: serializer.fromJson<String?>(json['metadata']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'companyId': serializer.toJson<String?>(companyId),
      'metadata': serializer.toJson<String?>(metadata),
      'isActive': serializer.toJson<bool>(isActive),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  Society copyWith(
          {String? id,
          String? name,
          Value<String?> companyId = const Value.absent(),
          Value<String?> metadata = const Value.absent(),
          bool? isActive,
          String? updatedAt}) =>
      Society(
        id: id ?? this.id,
        name: name ?? this.name,
        companyId: companyId.present ? companyId.value : this.companyId,
        metadata: metadata.present ? metadata.value : this.metadata,
        isActive: isActive ?? this.isActive,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Society copyWithCompanion(SocietiesCompanion data) {
    return Society(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      metadata: data.metadata.present ? data.metadata.value : this.metadata,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Society(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('companyId: $companyId, ')
          ..write('metadata: $metadata, ')
          ..write('isActive: $isActive, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, companyId, metadata, isActive, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Society &&
          other.id == this.id &&
          other.name == this.name &&
          other.companyId == this.companyId &&
          other.metadata == this.metadata &&
          other.isActive == this.isActive &&
          other.updatedAt == this.updatedAt);
}

class SocietiesCompanion extends UpdateCompanion<Society> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> companyId;
  final Value<String?> metadata;
  final Value<bool> isActive;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const SocietiesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.companyId = const Value.absent(),
    this.metadata = const Value.absent(),
    this.isActive = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SocietiesCompanion.insert({
    required String id,
    required String name,
    this.companyId = const Value.absent(),
    this.metadata = const Value.absent(),
    this.isActive = const Value.absent(),
    required String updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        updatedAt = Value(updatedAt);
  static Insertable<Society> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? companyId,
    Expression<String>? metadata,
    Expression<bool>? isActive,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (companyId != null) 'company_id': companyId,
      if (metadata != null) 'metadata': metadata,
      if (isActive != null) 'is_active': isActive,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SocietiesCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String?>? companyId,
      Value<String?>? metadata,
      Value<bool>? isActive,
      Value<String>? updatedAt,
      Value<int>? rowid}) {
    return SocietiesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      companyId: companyId ?? this.companyId,
      metadata: metadata ?? this.metadata,
      isActive: isActive ?? this.isActive,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (metadata.present) {
      map['metadata'] = Variable<String>(metadata.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SocietiesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('companyId: $companyId, ')
          ..write('metadata: $metadata, ')
          ..write('isActive: $isActive, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BlocksTable extends Blocks with TableInfo<$BlocksTable, Block> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BlocksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _societyIdMeta =
      const VerificationMeta('societyId');
  @override
  late final GeneratedColumn<String> societyId = GeneratedColumn<String>(
      'society_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES societies (id)'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _companyIdMeta =
      const VerificationMeta('companyId');
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
      'company_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _metadataMeta =
      const VerificationMeta('metadata');
  @override
  late final GeneratedColumn<String> metadata = GeneratedColumn<String>(
      'metadata', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isActiveMeta =
      const VerificationMeta('isActive');
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
      'is_active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_active" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, societyId, name, companyId, metadata, isActive, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'blocks';
  @override
  VerificationContext validateIntegrity(Insertable<Block> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('society_id')) {
      context.handle(_societyIdMeta,
          societyId.isAcceptableOrUnknown(data['society_id']!, _societyIdMeta));
    } else if (isInserting) {
      context.missing(_societyIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(_companyIdMeta,
          companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta));
    }
    if (data.containsKey('metadata')) {
      context.handle(_metadataMeta,
          metadata.isAcceptableOrUnknown(data['metadata']!, _metadataMeta));
    }
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Block map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Block(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      societyId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}society_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      companyId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}company_id']),
      metadata: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}metadata']),
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $BlocksTable createAlias(String alias) {
    return $BlocksTable(attachedDatabase, alias);
  }
}

class Block extends DataClass implements Insertable<Block> {
  final String id;
  final String societyId;
  final String name;
  final String? companyId;
  final String? metadata;
  final bool isActive;
  final String updatedAt;
  const Block(
      {required this.id,
      required this.societyId,
      required this.name,
      this.companyId,
      this.metadata,
      required this.isActive,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['society_id'] = Variable<String>(societyId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || companyId != null) {
      map['company_id'] = Variable<String>(companyId);
    }
    if (!nullToAbsent || metadata != null) {
      map['metadata'] = Variable<String>(metadata);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  BlocksCompanion toCompanion(bool nullToAbsent) {
    return BlocksCompanion(
      id: Value(id),
      societyId: Value(societyId),
      name: Value(name),
      companyId: companyId == null && nullToAbsent
          ? const Value.absent()
          : Value(companyId),
      metadata: metadata == null && nullToAbsent
          ? const Value.absent()
          : Value(metadata),
      isActive: Value(isActive),
      updatedAt: Value(updatedAt),
    );
  }

  factory Block.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Block(
      id: serializer.fromJson<String>(json['id']),
      societyId: serializer.fromJson<String>(json['societyId']),
      name: serializer.fromJson<String>(json['name']),
      companyId: serializer.fromJson<String?>(json['companyId']),
      metadata: serializer.fromJson<String?>(json['metadata']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'societyId': serializer.toJson<String>(societyId),
      'name': serializer.toJson<String>(name),
      'companyId': serializer.toJson<String?>(companyId),
      'metadata': serializer.toJson<String?>(metadata),
      'isActive': serializer.toJson<bool>(isActive),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  Block copyWith(
          {String? id,
          String? societyId,
          String? name,
          Value<String?> companyId = const Value.absent(),
          Value<String?> metadata = const Value.absent(),
          bool? isActive,
          String? updatedAt}) =>
      Block(
        id: id ?? this.id,
        societyId: societyId ?? this.societyId,
        name: name ?? this.name,
        companyId: companyId.present ? companyId.value : this.companyId,
        metadata: metadata.present ? metadata.value : this.metadata,
        isActive: isActive ?? this.isActive,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Block copyWithCompanion(BlocksCompanion data) {
    return Block(
      id: data.id.present ? data.id.value : this.id,
      societyId: data.societyId.present ? data.societyId.value : this.societyId,
      name: data.name.present ? data.name.value : this.name,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      metadata: data.metadata.present ? data.metadata.value : this.metadata,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Block(')
          ..write('id: $id, ')
          ..write('societyId: $societyId, ')
          ..write('name: $name, ')
          ..write('companyId: $companyId, ')
          ..write('metadata: $metadata, ')
          ..write('isActive: $isActive, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, societyId, name, companyId, metadata, isActive, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Block &&
          other.id == this.id &&
          other.societyId == this.societyId &&
          other.name == this.name &&
          other.companyId == this.companyId &&
          other.metadata == this.metadata &&
          other.isActive == this.isActive &&
          other.updatedAt == this.updatedAt);
}

class BlocksCompanion extends UpdateCompanion<Block> {
  final Value<String> id;
  final Value<String> societyId;
  final Value<String> name;
  final Value<String?> companyId;
  final Value<String?> metadata;
  final Value<bool> isActive;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const BlocksCompanion({
    this.id = const Value.absent(),
    this.societyId = const Value.absent(),
    this.name = const Value.absent(),
    this.companyId = const Value.absent(),
    this.metadata = const Value.absent(),
    this.isActive = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BlocksCompanion.insert({
    required String id,
    required String societyId,
    required String name,
    this.companyId = const Value.absent(),
    this.metadata = const Value.absent(),
    this.isActive = const Value.absent(),
    required String updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        societyId = Value(societyId),
        name = Value(name),
        updatedAt = Value(updatedAt);
  static Insertable<Block> custom({
    Expression<String>? id,
    Expression<String>? societyId,
    Expression<String>? name,
    Expression<String>? companyId,
    Expression<String>? metadata,
    Expression<bool>? isActive,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (societyId != null) 'society_id': societyId,
      if (name != null) 'name': name,
      if (companyId != null) 'company_id': companyId,
      if (metadata != null) 'metadata': metadata,
      if (isActive != null) 'is_active': isActive,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BlocksCompanion copyWith(
      {Value<String>? id,
      Value<String>? societyId,
      Value<String>? name,
      Value<String?>? companyId,
      Value<String?>? metadata,
      Value<bool>? isActive,
      Value<String>? updatedAt,
      Value<int>? rowid}) {
    return BlocksCompanion(
      id: id ?? this.id,
      societyId: societyId ?? this.societyId,
      name: name ?? this.name,
      companyId: companyId ?? this.companyId,
      metadata: metadata ?? this.metadata,
      isActive: isActive ?? this.isActive,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (societyId.present) {
      map['society_id'] = Variable<String>(societyId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (metadata.present) {
      map['metadata'] = Variable<String>(metadata.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BlocksCompanion(')
          ..write('id: $id, ')
          ..write('societyId: $societyId, ')
          ..write('name: $name, ')
          ..write('companyId: $companyId, ')
          ..write('metadata: $metadata, ')
          ..write('isActive: $isActive, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PropertiesTable extends Properties
    with TableInfo<$PropertiesTable, Property> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PropertiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _companyIdMeta =
      const VerificationMeta('companyId');
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
      'company_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdByMeta =
      const VerificationMeta('createdBy');
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
      'created_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _propertyNameMeta =
      const VerificationMeta('propertyName');
  @override
  late final GeneratedColumn<String> propertyName = GeneratedColumn<String>(
      'property_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<int> price = GeneratedColumn<int>(
      'price', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _remarksMeta =
      const VerificationMeta('remarks');
  @override
  late final GeneratedColumn<String> remarks = GeneratedColumn<String>(
      'remarks', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _clientNameMeta =
      const VerificationMeta('clientName');
  @override
  late final GeneratedColumn<String> clientName = GeneratedColumn<String>(
      'client_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _fileNoMeta = const VerificationMeta('fileNo');
  @override
  late final GeneratedColumn<String> fileNo = GeneratedColumn<String>(
      'file_no', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _referenceNoMeta =
      const VerificationMeta('referenceNo');
  @override
  late final GeneratedColumn<String> referenceNo = GeneratedColumn<String>(
      'reference_no', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _demandMeta = const VerificationMeta('demand');
  @override
  late final GeneratedColumn<int> demand = GeneratedColumn<int>(
      'demand', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _saleStatusMeta =
      const VerificationMeta('saleStatus');
  @override
  late final GeneratedColumn<String> saleStatus = GeneratedColumn<String>(
      'sale_status', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cnicMeta = const VerificationMeta('cnic');
  @override
  late final GeneratedColumn<String> cnic = GeneratedColumn<String>(
      'cnic', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _societyIdMeta =
      const VerificationMeta('societyId');
  @override
  late final GeneratedColumn<String> societyId = GeneratedColumn<String>(
      'society_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES societies (id)'));
  static const VerificationMeta _blockIdMeta =
      const VerificationMeta('blockId');
  @override
  late final GeneratedColumn<String> blockId = GeneratedColumn<String>(
      'block_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES blocks (id)'));
  static const VerificationMeta _isActiveMeta =
      const VerificationMeta('isActive');
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
      'is_active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_active" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        companyId,
        createdBy,
        propertyName,
        price,
        remarks,
        clientName,
        fileNo,
        referenceNo,
        demand,
        saleStatus,
        cnic,
        societyId,
        blockId,
        isActive,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'properties';
  @override
  VerificationContext validateIntegrity(Insertable<Property> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(_companyIdMeta,
          companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta));
    }
    if (data.containsKey('created_by')) {
      context.handle(_createdByMeta,
          createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta));
    }
    if (data.containsKey('property_name')) {
      context.handle(
          _propertyNameMeta,
          propertyName.isAcceptableOrUnknown(
              data['property_name']!, _propertyNameMeta));
    } else if (isInserting) {
      context.missing(_propertyNameMeta);
    }
    if (data.containsKey('price')) {
      context.handle(
          _priceMeta, price.isAcceptableOrUnknown(data['price']!, _priceMeta));
    }
    if (data.containsKey('remarks')) {
      context.handle(_remarksMeta,
          remarks.isAcceptableOrUnknown(data['remarks']!, _remarksMeta));
    }
    if (data.containsKey('client_name')) {
      context.handle(
          _clientNameMeta,
          clientName.isAcceptableOrUnknown(
              data['client_name']!, _clientNameMeta));
    }
    if (data.containsKey('file_no')) {
      context.handle(_fileNoMeta,
          fileNo.isAcceptableOrUnknown(data['file_no']!, _fileNoMeta));
    }
    if (data.containsKey('reference_no')) {
      context.handle(
          _referenceNoMeta,
          referenceNo.isAcceptableOrUnknown(
              data['reference_no']!, _referenceNoMeta));
    }
    if (data.containsKey('demand')) {
      context.handle(_demandMeta,
          demand.isAcceptableOrUnknown(data['demand']!, _demandMeta));
    }
    if (data.containsKey('sale_status')) {
      context.handle(
          _saleStatusMeta,
          saleStatus.isAcceptableOrUnknown(
              data['sale_status']!, _saleStatusMeta));
    }
    if (data.containsKey('cnic')) {
      context.handle(
          _cnicMeta, cnic.isAcceptableOrUnknown(data['cnic']!, _cnicMeta));
    }
    if (data.containsKey('society_id')) {
      context.handle(_societyIdMeta,
          societyId.isAcceptableOrUnknown(data['society_id']!, _societyIdMeta));
    }
    if (data.containsKey('block_id')) {
      context.handle(_blockIdMeta,
          blockId.isAcceptableOrUnknown(data['block_id']!, _blockIdMeta));
    }
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Property map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Property(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      companyId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}company_id']),
      createdBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}created_by']),
      propertyName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}property_name'])!,
      price: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}price']),
      remarks: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}remarks']),
      clientName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}client_name']),
      fileNo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_no']),
      referenceNo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reference_no']),
      demand: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}demand']),
      saleStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sale_status']),
      cnic: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cnic']),
      societyId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}society_id']),
      blockId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}block_id']),
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $PropertiesTable createAlias(String alias) {
    return $PropertiesTable(attachedDatabase, alias);
  }
}

class Property extends DataClass implements Insertable<Property> {
  final String id;
  final String? companyId;
  final String? createdBy;
  final String propertyName;
  final int? price;
  final String? remarks;
  final String? clientName;
  final String? fileNo;
  final String? referenceNo;
  final int? demand;
  final String? saleStatus;
  final String? cnic;
  final String? societyId;
  final String? blockId;
  final bool isActive;
  final String updatedAt;
  const Property(
      {required this.id,
      this.companyId,
      this.createdBy,
      required this.propertyName,
      this.price,
      this.remarks,
      this.clientName,
      this.fileNo,
      this.referenceNo,
      this.demand,
      this.saleStatus,
      this.cnic,
      this.societyId,
      this.blockId,
      required this.isActive,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || companyId != null) {
      map['company_id'] = Variable<String>(companyId);
    }
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<String>(createdBy);
    }
    map['property_name'] = Variable<String>(propertyName);
    if (!nullToAbsent || price != null) {
      map['price'] = Variable<int>(price);
    }
    if (!nullToAbsent || remarks != null) {
      map['remarks'] = Variable<String>(remarks);
    }
    if (!nullToAbsent || clientName != null) {
      map['client_name'] = Variable<String>(clientName);
    }
    if (!nullToAbsent || fileNo != null) {
      map['file_no'] = Variable<String>(fileNo);
    }
    if (!nullToAbsent || referenceNo != null) {
      map['reference_no'] = Variable<String>(referenceNo);
    }
    if (!nullToAbsent || demand != null) {
      map['demand'] = Variable<int>(demand);
    }
    if (!nullToAbsent || saleStatus != null) {
      map['sale_status'] = Variable<String>(saleStatus);
    }
    if (!nullToAbsent || cnic != null) {
      map['cnic'] = Variable<String>(cnic);
    }
    if (!nullToAbsent || societyId != null) {
      map['society_id'] = Variable<String>(societyId);
    }
    if (!nullToAbsent || blockId != null) {
      map['block_id'] = Variable<String>(blockId);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  PropertiesCompanion toCompanion(bool nullToAbsent) {
    return PropertiesCompanion(
      id: Value(id),
      companyId: companyId == null && nullToAbsent
          ? const Value.absent()
          : Value(companyId),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      propertyName: Value(propertyName),
      price:
          price == null && nullToAbsent ? const Value.absent() : Value(price),
      remarks: remarks == null && nullToAbsent
          ? const Value.absent()
          : Value(remarks),
      clientName: clientName == null && nullToAbsent
          ? const Value.absent()
          : Value(clientName),
      fileNo:
          fileNo == null && nullToAbsent ? const Value.absent() : Value(fileNo),
      referenceNo: referenceNo == null && nullToAbsent
          ? const Value.absent()
          : Value(referenceNo),
      demand:
          demand == null && nullToAbsent ? const Value.absent() : Value(demand),
      saleStatus: saleStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(saleStatus),
      cnic: cnic == null && nullToAbsent ? const Value.absent() : Value(cnic),
      societyId: societyId == null && nullToAbsent
          ? const Value.absent()
          : Value(societyId),
      blockId: blockId == null && nullToAbsent
          ? const Value.absent()
          : Value(blockId),
      isActive: Value(isActive),
      updatedAt: Value(updatedAt),
    );
  }

  factory Property.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Property(
      id: serializer.fromJson<String>(json['id']),
      companyId: serializer.fromJson<String?>(json['companyId']),
      createdBy: serializer.fromJson<String?>(json['createdBy']),
      propertyName: serializer.fromJson<String>(json['propertyName']),
      price: serializer.fromJson<int?>(json['price']),
      remarks: serializer.fromJson<String?>(json['remarks']),
      clientName: serializer.fromJson<String?>(json['clientName']),
      fileNo: serializer.fromJson<String?>(json['fileNo']),
      referenceNo: serializer.fromJson<String?>(json['referenceNo']),
      demand: serializer.fromJson<int?>(json['demand']),
      saleStatus: serializer.fromJson<String?>(json['saleStatus']),
      cnic: serializer.fromJson<String?>(json['cnic']),
      societyId: serializer.fromJson<String?>(json['societyId']),
      blockId: serializer.fromJson<String?>(json['blockId']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'companyId': serializer.toJson<String?>(companyId),
      'createdBy': serializer.toJson<String?>(createdBy),
      'propertyName': serializer.toJson<String>(propertyName),
      'price': serializer.toJson<int?>(price),
      'remarks': serializer.toJson<String?>(remarks),
      'clientName': serializer.toJson<String?>(clientName),
      'fileNo': serializer.toJson<String?>(fileNo),
      'referenceNo': serializer.toJson<String?>(referenceNo),
      'demand': serializer.toJson<int?>(demand),
      'saleStatus': serializer.toJson<String?>(saleStatus),
      'cnic': serializer.toJson<String?>(cnic),
      'societyId': serializer.toJson<String?>(societyId),
      'blockId': serializer.toJson<String?>(blockId),
      'isActive': serializer.toJson<bool>(isActive),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  Property copyWith(
          {String? id,
          Value<String?> companyId = const Value.absent(),
          Value<String?> createdBy = const Value.absent(),
          String? propertyName,
          Value<int?> price = const Value.absent(),
          Value<String?> remarks = const Value.absent(),
          Value<String?> clientName = const Value.absent(),
          Value<String?> fileNo = const Value.absent(),
          Value<String?> referenceNo = const Value.absent(),
          Value<int?> demand = const Value.absent(),
          Value<String?> saleStatus = const Value.absent(),
          Value<String?> cnic = const Value.absent(),
          Value<String?> societyId = const Value.absent(),
          Value<String?> blockId = const Value.absent(),
          bool? isActive,
          String? updatedAt}) =>
      Property(
        id: id ?? this.id,
        companyId: companyId.present ? companyId.value : this.companyId,
        createdBy: createdBy.present ? createdBy.value : this.createdBy,
        propertyName: propertyName ?? this.propertyName,
        price: price.present ? price.value : this.price,
        remarks: remarks.present ? remarks.value : this.remarks,
        clientName: clientName.present ? clientName.value : this.clientName,
        fileNo: fileNo.present ? fileNo.value : this.fileNo,
        referenceNo: referenceNo.present ? referenceNo.value : this.referenceNo,
        demand: demand.present ? demand.value : this.demand,
        saleStatus: saleStatus.present ? saleStatus.value : this.saleStatus,
        cnic: cnic.present ? cnic.value : this.cnic,
        societyId: societyId.present ? societyId.value : this.societyId,
        blockId: blockId.present ? blockId.value : this.blockId,
        isActive: isActive ?? this.isActive,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Property copyWithCompanion(PropertiesCompanion data) {
    return Property(
      id: data.id.present ? data.id.value : this.id,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      propertyName: data.propertyName.present
          ? data.propertyName.value
          : this.propertyName,
      price: data.price.present ? data.price.value : this.price,
      remarks: data.remarks.present ? data.remarks.value : this.remarks,
      clientName:
          data.clientName.present ? data.clientName.value : this.clientName,
      fileNo: data.fileNo.present ? data.fileNo.value : this.fileNo,
      referenceNo:
          data.referenceNo.present ? data.referenceNo.value : this.referenceNo,
      demand: data.demand.present ? data.demand.value : this.demand,
      saleStatus:
          data.saleStatus.present ? data.saleStatus.value : this.saleStatus,
      cnic: data.cnic.present ? data.cnic.value : this.cnic,
      societyId: data.societyId.present ? data.societyId.value : this.societyId,
      blockId: data.blockId.present ? data.blockId.value : this.blockId,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Property(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('createdBy: $createdBy, ')
          ..write('propertyName: $propertyName, ')
          ..write('price: $price, ')
          ..write('remarks: $remarks, ')
          ..write('clientName: $clientName, ')
          ..write('fileNo: $fileNo, ')
          ..write('referenceNo: $referenceNo, ')
          ..write('demand: $demand, ')
          ..write('saleStatus: $saleStatus, ')
          ..write('cnic: $cnic, ')
          ..write('societyId: $societyId, ')
          ..write('blockId: $blockId, ')
          ..write('isActive: $isActive, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      companyId,
      createdBy,
      propertyName,
      price,
      remarks,
      clientName,
      fileNo,
      referenceNo,
      demand,
      saleStatus,
      cnic,
      societyId,
      blockId,
      isActive,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Property &&
          other.id == this.id &&
          other.companyId == this.companyId &&
          other.createdBy == this.createdBy &&
          other.propertyName == this.propertyName &&
          other.price == this.price &&
          other.remarks == this.remarks &&
          other.clientName == this.clientName &&
          other.fileNo == this.fileNo &&
          other.referenceNo == this.referenceNo &&
          other.demand == this.demand &&
          other.saleStatus == this.saleStatus &&
          other.cnic == this.cnic &&
          other.societyId == this.societyId &&
          other.blockId == this.blockId &&
          other.isActive == this.isActive &&
          other.updatedAt == this.updatedAt);
}

class PropertiesCompanion extends UpdateCompanion<Property> {
  final Value<String> id;
  final Value<String?> companyId;
  final Value<String?> createdBy;
  final Value<String> propertyName;
  final Value<int?> price;
  final Value<String?> remarks;
  final Value<String?> clientName;
  final Value<String?> fileNo;
  final Value<String?> referenceNo;
  final Value<int?> demand;
  final Value<String?> saleStatus;
  final Value<String?> cnic;
  final Value<String?> societyId;
  final Value<String?> blockId;
  final Value<bool> isActive;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const PropertiesCompanion({
    this.id = const Value.absent(),
    this.companyId = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.propertyName = const Value.absent(),
    this.price = const Value.absent(),
    this.remarks = const Value.absent(),
    this.clientName = const Value.absent(),
    this.fileNo = const Value.absent(),
    this.referenceNo = const Value.absent(),
    this.demand = const Value.absent(),
    this.saleStatus = const Value.absent(),
    this.cnic = const Value.absent(),
    this.societyId = const Value.absent(),
    this.blockId = const Value.absent(),
    this.isActive = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PropertiesCompanion.insert({
    required String id,
    this.companyId = const Value.absent(),
    this.createdBy = const Value.absent(),
    required String propertyName,
    this.price = const Value.absent(),
    this.remarks = const Value.absent(),
    this.clientName = const Value.absent(),
    this.fileNo = const Value.absent(),
    this.referenceNo = const Value.absent(),
    this.demand = const Value.absent(),
    this.saleStatus = const Value.absent(),
    this.cnic = const Value.absent(),
    this.societyId = const Value.absent(),
    this.blockId = const Value.absent(),
    this.isActive = const Value.absent(),
    required String updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        propertyName = Value(propertyName),
        updatedAt = Value(updatedAt);
  static Insertable<Property> custom({
    Expression<String>? id,
    Expression<String>? companyId,
    Expression<String>? createdBy,
    Expression<String>? propertyName,
    Expression<int>? price,
    Expression<String>? remarks,
    Expression<String>? clientName,
    Expression<String>? fileNo,
    Expression<String>? referenceNo,
    Expression<int>? demand,
    Expression<String>? saleStatus,
    Expression<String>? cnic,
    Expression<String>? societyId,
    Expression<String>? blockId,
    Expression<bool>? isActive,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (companyId != null) 'company_id': companyId,
      if (createdBy != null) 'created_by': createdBy,
      if (propertyName != null) 'property_name': propertyName,
      if (price != null) 'price': price,
      if (remarks != null) 'remarks': remarks,
      if (clientName != null) 'client_name': clientName,
      if (fileNo != null) 'file_no': fileNo,
      if (referenceNo != null) 'reference_no': referenceNo,
      if (demand != null) 'demand': demand,
      if (saleStatus != null) 'sale_status': saleStatus,
      if (cnic != null) 'cnic': cnic,
      if (societyId != null) 'society_id': societyId,
      if (blockId != null) 'block_id': blockId,
      if (isActive != null) 'is_active': isActive,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PropertiesCompanion copyWith(
      {Value<String>? id,
      Value<String?>? companyId,
      Value<String?>? createdBy,
      Value<String>? propertyName,
      Value<int?>? price,
      Value<String?>? remarks,
      Value<String?>? clientName,
      Value<String?>? fileNo,
      Value<String?>? referenceNo,
      Value<int?>? demand,
      Value<String?>? saleStatus,
      Value<String?>? cnic,
      Value<String?>? societyId,
      Value<String?>? blockId,
      Value<bool>? isActive,
      Value<String>? updatedAt,
      Value<int>? rowid}) {
    return PropertiesCompanion(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      createdBy: createdBy ?? this.createdBy,
      propertyName: propertyName ?? this.propertyName,
      price: price ?? this.price,
      remarks: remarks ?? this.remarks,
      clientName: clientName ?? this.clientName,
      fileNo: fileNo ?? this.fileNo,
      referenceNo: referenceNo ?? this.referenceNo,
      demand: demand ?? this.demand,
      saleStatus: saleStatus ?? this.saleStatus,
      cnic: cnic ?? this.cnic,
      societyId: societyId ?? this.societyId,
      blockId: blockId ?? this.blockId,
      isActive: isActive ?? this.isActive,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (propertyName.present) {
      map['property_name'] = Variable<String>(propertyName.value);
    }
    if (price.present) {
      map['price'] = Variable<int>(price.value);
    }
    if (remarks.present) {
      map['remarks'] = Variable<String>(remarks.value);
    }
    if (clientName.present) {
      map['client_name'] = Variable<String>(clientName.value);
    }
    if (fileNo.present) {
      map['file_no'] = Variable<String>(fileNo.value);
    }
    if (referenceNo.present) {
      map['reference_no'] = Variable<String>(referenceNo.value);
    }
    if (demand.present) {
      map['demand'] = Variable<int>(demand.value);
    }
    if (saleStatus.present) {
      map['sale_status'] = Variable<String>(saleStatus.value);
    }
    if (cnic.present) {
      map['cnic'] = Variable<String>(cnic.value);
    }
    if (societyId.present) {
      map['society_id'] = Variable<String>(societyId.value);
    }
    if (blockId.present) {
      map['block_id'] = Variable<String>(blockId.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PropertiesCompanion(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('createdBy: $createdBy, ')
          ..write('propertyName: $propertyName, ')
          ..write('price: $price, ')
          ..write('remarks: $remarks, ')
          ..write('clientName: $clientName, ')
          ..write('fileNo: $fileNo, ')
          ..write('referenceNo: $referenceNo, ')
          ..write('demand: $demand, ')
          ..write('saleStatus: $saleStatus, ')
          ..write('cnic: $cnic, ')
          ..write('societyId: $societyId, ')
          ..write('blockId: $blockId, ')
          ..write('isActive: $isActive, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PropertyCommentsTable extends PropertyComments
    with TableInfo<$PropertyCommentsTable, PropertyComment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PropertyCommentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _parentIdMeta =
      const VerificationMeta('parentId');
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
      'parent_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES properties (id)'));
  static const VerificationMeta _companyIdMeta =
      const VerificationMeta('companyId');
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
      'company_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _commentMeta =
      const VerificationMeta('comment');
  @override
  late final GeneratedColumn<String> comment = GeneratedColumn<String>(
      'comment', aliasedName, false,
      check: () => ComparableExpr(comment.length).isSmallerOrEqualValue(500),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, parentId, companyId, comment, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'property_comments';
  @override
  VerificationContext validateIntegrity(Insertable<PropertyComment> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(_parentIdMeta,
          parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta));
    } else if (isInserting) {
      context.missing(_parentIdMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(_companyIdMeta,
          companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta));
    }
    if (data.containsKey('comment')) {
      context.handle(_commentMeta,
          comment.isAcceptableOrUnknown(data['comment']!, _commentMeta));
    } else if (isInserting) {
      context.missing(_commentMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PropertyComment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PropertyComment(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      parentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}parent_id'])!,
      companyId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}company_id']),
      comment: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}comment'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $PropertyCommentsTable createAlias(String alias) {
    return $PropertyCommentsTable(attachedDatabase, alias);
  }
}

class PropertyComment extends DataClass implements Insertable<PropertyComment> {
  final String id;
  final String parentId;
  final String? companyId;
  final String comment;
  final String updatedAt;
  const PropertyComment(
      {required this.id,
      required this.parentId,
      this.companyId,
      required this.comment,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['parent_id'] = Variable<String>(parentId);
    if (!nullToAbsent || companyId != null) {
      map['company_id'] = Variable<String>(companyId);
    }
    map['comment'] = Variable<String>(comment);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  PropertyCommentsCompanion toCompanion(bool nullToAbsent) {
    return PropertyCommentsCompanion(
      id: Value(id),
      parentId: Value(parentId),
      companyId: companyId == null && nullToAbsent
          ? const Value.absent()
          : Value(companyId),
      comment: Value(comment),
      updatedAt: Value(updatedAt),
    );
  }

  factory PropertyComment.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PropertyComment(
      id: serializer.fromJson<String>(json['id']),
      parentId: serializer.fromJson<String>(json['parentId']),
      companyId: serializer.fromJson<String?>(json['companyId']),
      comment: serializer.fromJson<String>(json['comment']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'parentId': serializer.toJson<String>(parentId),
      'companyId': serializer.toJson<String?>(companyId),
      'comment': serializer.toJson<String>(comment),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  PropertyComment copyWith(
          {String? id,
          String? parentId,
          Value<String?> companyId = const Value.absent(),
          String? comment,
          String? updatedAt}) =>
      PropertyComment(
        id: id ?? this.id,
        parentId: parentId ?? this.parentId,
        companyId: companyId.present ? companyId.value : this.companyId,
        comment: comment ?? this.comment,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  PropertyComment copyWithCompanion(PropertyCommentsCompanion data) {
    return PropertyComment(
      id: data.id.present ? data.id.value : this.id,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      comment: data.comment.present ? data.comment.value : this.comment,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PropertyComment(')
          ..write('id: $id, ')
          ..write('parentId: $parentId, ')
          ..write('companyId: $companyId, ')
          ..write('comment: $comment, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, parentId, companyId, comment, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PropertyComment &&
          other.id == this.id &&
          other.parentId == this.parentId &&
          other.companyId == this.companyId &&
          other.comment == this.comment &&
          other.updatedAt == this.updatedAt);
}

class PropertyCommentsCompanion extends UpdateCompanion<PropertyComment> {
  final Value<String> id;
  final Value<String> parentId;
  final Value<String?> companyId;
  final Value<String> comment;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const PropertyCommentsCompanion({
    this.id = const Value.absent(),
    this.parentId = const Value.absent(),
    this.companyId = const Value.absent(),
    this.comment = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PropertyCommentsCompanion.insert({
    required String id,
    required String parentId,
    this.companyId = const Value.absent(),
    required String comment,
    required String updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        parentId = Value(parentId),
        comment = Value(comment),
        updatedAt = Value(updatedAt);
  static Insertable<PropertyComment> custom({
    Expression<String>? id,
    Expression<String>? parentId,
    Expression<String>? companyId,
    Expression<String>? comment,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (parentId != null) 'parent_id': parentId,
      if (companyId != null) 'company_id': companyId,
      if (comment != null) 'comment': comment,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PropertyCommentsCompanion copyWith(
      {Value<String>? id,
      Value<String>? parentId,
      Value<String?>? companyId,
      Value<String>? comment,
      Value<String>? updatedAt,
      Value<int>? rowid}) {
    return PropertyCommentsCompanion(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      companyId: companyId ?? this.companyId,
      comment: comment ?? this.comment,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (comment.present) {
      map['comment'] = Variable<String>(comment.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PropertyCommentsCompanion(')
          ..write('id: $id, ')
          ..write('parentId: $parentId, ')
          ..write('companyId: $companyId, ')
          ..write('comment: $comment, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FilesTableTable extends FilesTable
    with TableInfo<$FilesTableTable, FilesTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FilesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _companyIdMeta =
      const VerificationMeta('companyId');
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
      'company_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdByMeta =
      const VerificationMeta('createdBy');
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
      'created_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _clientNameMeta =
      const VerificationMeta('clientName');
  @override
  late final GeneratedColumn<String> clientName = GeneratedColumn<String>(
      'client_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _fileNoMeta = const VerificationMeta('fileNo');
  @override
  late final GeneratedColumn<String> fileNo = GeneratedColumn<String>(
      'file_no', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _referenceNoMeta =
      const VerificationMeta('referenceNo');
  @override
  late final GeneratedColumn<String> referenceNo = GeneratedColumn<String>(
      'reference_no', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _demandMeta = const VerificationMeta('demand');
  @override
  late final GeneratedColumn<int> demand = GeneratedColumn<int>(
      'demand', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _saleStatusMeta =
      const VerificationMeta('saleStatus');
  @override
  late final GeneratedColumn<String> saleStatus = GeneratedColumn<String>(
      'sale_status', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _mobileNoMeta =
      const VerificationMeta('mobileNo');
  @override
  late final GeneratedColumn<String> mobileNo = GeneratedColumn<String>(
      'mobile_no', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cnicMeta = const VerificationMeta('cnic');
  @override
  late final GeneratedColumn<String> cnic = GeneratedColumn<String>(
      'cnic', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _societyIdMeta =
      const VerificationMeta('societyId');
  @override
  late final GeneratedColumn<String> societyId = GeneratedColumn<String>(
      'society_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES societies (id)'));
  static const VerificationMeta _blockIdMeta =
      const VerificationMeta('blockId');
  @override
  late final GeneratedColumn<String> blockId = GeneratedColumn<String>(
      'block_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES blocks (id)'));
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
      'path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _remarksMeta =
      const VerificationMeta('remarks');
  @override
  late final GeneratedColumn<String> remarks = GeneratedColumn<String>(
      'remarks', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isActiveMeta =
      const VerificationMeta('isActive');
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
      'is_active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_active" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        companyId,
        createdBy,
        name,
        clientName,
        fileNo,
        referenceNo,
        demand,
        saleStatus,
        mobileNo,
        cnic,
        societyId,
        blockId,
        path,
        remarks,
        isActive,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'files_table';
  @override
  VerificationContext validateIntegrity(Insertable<FilesTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(_companyIdMeta,
          companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta));
    }
    if (data.containsKey('created_by')) {
      context.handle(_createdByMeta,
          createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('client_name')) {
      context.handle(
          _clientNameMeta,
          clientName.isAcceptableOrUnknown(
              data['client_name']!, _clientNameMeta));
    }
    if (data.containsKey('file_no')) {
      context.handle(_fileNoMeta,
          fileNo.isAcceptableOrUnknown(data['file_no']!, _fileNoMeta));
    }
    if (data.containsKey('reference_no')) {
      context.handle(
          _referenceNoMeta,
          referenceNo.isAcceptableOrUnknown(
              data['reference_no']!, _referenceNoMeta));
    }
    if (data.containsKey('demand')) {
      context.handle(_demandMeta,
          demand.isAcceptableOrUnknown(data['demand']!, _demandMeta));
    }
    if (data.containsKey('sale_status')) {
      context.handle(
          _saleStatusMeta,
          saleStatus.isAcceptableOrUnknown(
              data['sale_status']!, _saleStatusMeta));
    }
    if (data.containsKey('mobile_no')) {
      context.handle(_mobileNoMeta,
          mobileNo.isAcceptableOrUnknown(data['mobile_no']!, _mobileNoMeta));
    }
    if (data.containsKey('cnic')) {
      context.handle(
          _cnicMeta, cnic.isAcceptableOrUnknown(data['cnic']!, _cnicMeta));
    }
    if (data.containsKey('society_id')) {
      context.handle(_societyIdMeta,
          societyId.isAcceptableOrUnknown(data['society_id']!, _societyIdMeta));
    }
    if (data.containsKey('block_id')) {
      context.handle(_blockIdMeta,
          blockId.isAcceptableOrUnknown(data['block_id']!, _blockIdMeta));
    }
    if (data.containsKey('path')) {
      context.handle(
          _pathMeta, path.isAcceptableOrUnknown(data['path']!, _pathMeta));
    }
    if (data.containsKey('remarks')) {
      context.handle(_remarksMeta,
          remarks.isAcceptableOrUnknown(data['remarks']!, _remarksMeta));
    }
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FilesTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FilesTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      companyId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}company_id']),
      createdBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}created_by']),
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      clientName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}client_name']),
      fileNo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_no']),
      referenceNo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reference_no']),
      demand: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}demand']),
      saleStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sale_status']),
      mobileNo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mobile_no']),
      cnic: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cnic']),
      societyId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}society_id']),
      blockId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}block_id']),
      path: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}path']),
      remarks: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}remarks']),
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $FilesTableTable createAlias(String alias) {
    return $FilesTableTable(attachedDatabase, alias);
  }
}

class FilesTableData extends DataClass implements Insertable<FilesTableData> {
  final String id;
  final String? companyId;
  final String? createdBy;
  final String name;
  final String? clientName;
  final String? fileNo;
  final String? referenceNo;
  final int? demand;
  final String? saleStatus;
  final String? mobileNo;
  final String? cnic;
  final String? societyId;
  final String? blockId;
  final String? path;
  final String? remarks;
  final bool isActive;
  final String updatedAt;
  const FilesTableData(
      {required this.id,
      this.companyId,
      this.createdBy,
      required this.name,
      this.clientName,
      this.fileNo,
      this.referenceNo,
      this.demand,
      this.saleStatus,
      this.mobileNo,
      this.cnic,
      this.societyId,
      this.blockId,
      this.path,
      this.remarks,
      required this.isActive,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || companyId != null) {
      map['company_id'] = Variable<String>(companyId);
    }
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<String>(createdBy);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || clientName != null) {
      map['client_name'] = Variable<String>(clientName);
    }
    if (!nullToAbsent || fileNo != null) {
      map['file_no'] = Variable<String>(fileNo);
    }
    if (!nullToAbsent || referenceNo != null) {
      map['reference_no'] = Variable<String>(referenceNo);
    }
    if (!nullToAbsent || demand != null) {
      map['demand'] = Variable<int>(demand);
    }
    if (!nullToAbsent || saleStatus != null) {
      map['sale_status'] = Variable<String>(saleStatus);
    }
    if (!nullToAbsent || mobileNo != null) {
      map['mobile_no'] = Variable<String>(mobileNo);
    }
    if (!nullToAbsent || cnic != null) {
      map['cnic'] = Variable<String>(cnic);
    }
    if (!nullToAbsent || societyId != null) {
      map['society_id'] = Variable<String>(societyId);
    }
    if (!nullToAbsent || blockId != null) {
      map['block_id'] = Variable<String>(blockId);
    }
    if (!nullToAbsent || path != null) {
      map['path'] = Variable<String>(path);
    }
    if (!nullToAbsent || remarks != null) {
      map['remarks'] = Variable<String>(remarks);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  FilesTableCompanion toCompanion(bool nullToAbsent) {
    return FilesTableCompanion(
      id: Value(id),
      companyId: companyId == null && nullToAbsent
          ? const Value.absent()
          : Value(companyId),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      name: Value(name),
      clientName: clientName == null && nullToAbsent
          ? const Value.absent()
          : Value(clientName),
      fileNo:
          fileNo == null && nullToAbsent ? const Value.absent() : Value(fileNo),
      referenceNo: referenceNo == null && nullToAbsent
          ? const Value.absent()
          : Value(referenceNo),
      demand:
          demand == null && nullToAbsent ? const Value.absent() : Value(demand),
      saleStatus: saleStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(saleStatus),
      mobileNo: mobileNo == null && nullToAbsent
          ? const Value.absent()
          : Value(mobileNo),
      cnic: cnic == null && nullToAbsent ? const Value.absent() : Value(cnic),
      societyId: societyId == null && nullToAbsent
          ? const Value.absent()
          : Value(societyId),
      blockId: blockId == null && nullToAbsent
          ? const Value.absent()
          : Value(blockId),
      path: path == null && nullToAbsent ? const Value.absent() : Value(path),
      remarks: remarks == null && nullToAbsent
          ? const Value.absent()
          : Value(remarks),
      isActive: Value(isActive),
      updatedAt: Value(updatedAt),
    );
  }

  factory FilesTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FilesTableData(
      id: serializer.fromJson<String>(json['id']),
      companyId: serializer.fromJson<String?>(json['companyId']),
      createdBy: serializer.fromJson<String?>(json['createdBy']),
      name: serializer.fromJson<String>(json['name']),
      clientName: serializer.fromJson<String?>(json['clientName']),
      fileNo: serializer.fromJson<String?>(json['fileNo']),
      referenceNo: serializer.fromJson<String?>(json['referenceNo']),
      demand: serializer.fromJson<int?>(json['demand']),
      saleStatus: serializer.fromJson<String?>(json['saleStatus']),
      mobileNo: serializer.fromJson<String?>(json['mobileNo']),
      cnic: serializer.fromJson<String?>(json['cnic']),
      societyId: serializer.fromJson<String?>(json['societyId']),
      blockId: serializer.fromJson<String?>(json['blockId']),
      path: serializer.fromJson<String?>(json['path']),
      remarks: serializer.fromJson<String?>(json['remarks']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'companyId': serializer.toJson<String?>(companyId),
      'createdBy': serializer.toJson<String?>(createdBy),
      'name': serializer.toJson<String>(name),
      'clientName': serializer.toJson<String?>(clientName),
      'fileNo': serializer.toJson<String?>(fileNo),
      'referenceNo': serializer.toJson<String?>(referenceNo),
      'demand': serializer.toJson<int?>(demand),
      'saleStatus': serializer.toJson<String?>(saleStatus),
      'mobileNo': serializer.toJson<String?>(mobileNo),
      'cnic': serializer.toJson<String?>(cnic),
      'societyId': serializer.toJson<String?>(societyId),
      'blockId': serializer.toJson<String?>(blockId),
      'path': serializer.toJson<String?>(path),
      'remarks': serializer.toJson<String?>(remarks),
      'isActive': serializer.toJson<bool>(isActive),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  FilesTableData copyWith(
          {String? id,
          Value<String?> companyId = const Value.absent(),
          Value<String?> createdBy = const Value.absent(),
          String? name,
          Value<String?> clientName = const Value.absent(),
          Value<String?> fileNo = const Value.absent(),
          Value<String?> referenceNo = const Value.absent(),
          Value<int?> demand = const Value.absent(),
          Value<String?> saleStatus = const Value.absent(),
          Value<String?> mobileNo = const Value.absent(),
          Value<String?> cnic = const Value.absent(),
          Value<String?> societyId = const Value.absent(),
          Value<String?> blockId = const Value.absent(),
          Value<String?> path = const Value.absent(),
          Value<String?> remarks = const Value.absent(),
          bool? isActive,
          String? updatedAt}) =>
      FilesTableData(
        id: id ?? this.id,
        companyId: companyId.present ? companyId.value : this.companyId,
        createdBy: createdBy.present ? createdBy.value : this.createdBy,
        name: name ?? this.name,
        clientName: clientName.present ? clientName.value : this.clientName,
        fileNo: fileNo.present ? fileNo.value : this.fileNo,
        referenceNo: referenceNo.present ? referenceNo.value : this.referenceNo,
        demand: demand.present ? demand.value : this.demand,
        saleStatus: saleStatus.present ? saleStatus.value : this.saleStatus,
        mobileNo: mobileNo.present ? mobileNo.value : this.mobileNo,
        cnic: cnic.present ? cnic.value : this.cnic,
        societyId: societyId.present ? societyId.value : this.societyId,
        blockId: blockId.present ? blockId.value : this.blockId,
        path: path.present ? path.value : this.path,
        remarks: remarks.present ? remarks.value : this.remarks,
        isActive: isActive ?? this.isActive,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  FilesTableData copyWithCompanion(FilesTableCompanion data) {
    return FilesTableData(
      id: data.id.present ? data.id.value : this.id,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      name: data.name.present ? data.name.value : this.name,
      clientName:
          data.clientName.present ? data.clientName.value : this.clientName,
      fileNo: data.fileNo.present ? data.fileNo.value : this.fileNo,
      referenceNo:
          data.referenceNo.present ? data.referenceNo.value : this.referenceNo,
      demand: data.demand.present ? data.demand.value : this.demand,
      saleStatus:
          data.saleStatus.present ? data.saleStatus.value : this.saleStatus,
      mobileNo: data.mobileNo.present ? data.mobileNo.value : this.mobileNo,
      cnic: data.cnic.present ? data.cnic.value : this.cnic,
      societyId: data.societyId.present ? data.societyId.value : this.societyId,
      blockId: data.blockId.present ? data.blockId.value : this.blockId,
      path: data.path.present ? data.path.value : this.path,
      remarks: data.remarks.present ? data.remarks.value : this.remarks,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FilesTableData(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('createdBy: $createdBy, ')
          ..write('name: $name, ')
          ..write('clientName: $clientName, ')
          ..write('fileNo: $fileNo, ')
          ..write('referenceNo: $referenceNo, ')
          ..write('demand: $demand, ')
          ..write('saleStatus: $saleStatus, ')
          ..write('mobileNo: $mobileNo, ')
          ..write('cnic: $cnic, ')
          ..write('societyId: $societyId, ')
          ..write('blockId: $blockId, ')
          ..write('path: $path, ')
          ..write('remarks: $remarks, ')
          ..write('isActive: $isActive, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      companyId,
      createdBy,
      name,
      clientName,
      fileNo,
      referenceNo,
      demand,
      saleStatus,
      mobileNo,
      cnic,
      societyId,
      blockId,
      path,
      remarks,
      isActive,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FilesTableData &&
          other.id == this.id &&
          other.companyId == this.companyId &&
          other.createdBy == this.createdBy &&
          other.name == this.name &&
          other.clientName == this.clientName &&
          other.fileNo == this.fileNo &&
          other.referenceNo == this.referenceNo &&
          other.demand == this.demand &&
          other.saleStatus == this.saleStatus &&
          other.mobileNo == this.mobileNo &&
          other.cnic == this.cnic &&
          other.societyId == this.societyId &&
          other.blockId == this.blockId &&
          other.path == this.path &&
          other.remarks == this.remarks &&
          other.isActive == this.isActive &&
          other.updatedAt == this.updatedAt);
}

class FilesTableCompanion extends UpdateCompanion<FilesTableData> {
  final Value<String> id;
  final Value<String?> companyId;
  final Value<String?> createdBy;
  final Value<String> name;
  final Value<String?> clientName;
  final Value<String?> fileNo;
  final Value<String?> referenceNo;
  final Value<int?> demand;
  final Value<String?> saleStatus;
  final Value<String?> mobileNo;
  final Value<String?> cnic;
  final Value<String?> societyId;
  final Value<String?> blockId;
  final Value<String?> path;
  final Value<String?> remarks;
  final Value<bool> isActive;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const FilesTableCompanion({
    this.id = const Value.absent(),
    this.companyId = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.name = const Value.absent(),
    this.clientName = const Value.absent(),
    this.fileNo = const Value.absent(),
    this.referenceNo = const Value.absent(),
    this.demand = const Value.absent(),
    this.saleStatus = const Value.absent(),
    this.mobileNo = const Value.absent(),
    this.cnic = const Value.absent(),
    this.societyId = const Value.absent(),
    this.blockId = const Value.absent(),
    this.path = const Value.absent(),
    this.remarks = const Value.absent(),
    this.isActive = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FilesTableCompanion.insert({
    required String id,
    this.companyId = const Value.absent(),
    this.createdBy = const Value.absent(),
    required String name,
    this.clientName = const Value.absent(),
    this.fileNo = const Value.absent(),
    this.referenceNo = const Value.absent(),
    this.demand = const Value.absent(),
    this.saleStatus = const Value.absent(),
    this.mobileNo = const Value.absent(),
    this.cnic = const Value.absent(),
    this.societyId = const Value.absent(),
    this.blockId = const Value.absent(),
    this.path = const Value.absent(),
    this.remarks = const Value.absent(),
    this.isActive = const Value.absent(),
    required String updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        updatedAt = Value(updatedAt);
  static Insertable<FilesTableData> custom({
    Expression<String>? id,
    Expression<String>? companyId,
    Expression<String>? createdBy,
    Expression<String>? name,
    Expression<String>? clientName,
    Expression<String>? fileNo,
    Expression<String>? referenceNo,
    Expression<int>? demand,
    Expression<String>? saleStatus,
    Expression<String>? mobileNo,
    Expression<String>? cnic,
    Expression<String>? societyId,
    Expression<String>? blockId,
    Expression<String>? path,
    Expression<String>? remarks,
    Expression<bool>? isActive,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (companyId != null) 'company_id': companyId,
      if (createdBy != null) 'created_by': createdBy,
      if (name != null) 'name': name,
      if (clientName != null) 'client_name': clientName,
      if (fileNo != null) 'file_no': fileNo,
      if (referenceNo != null) 'reference_no': referenceNo,
      if (demand != null) 'demand': demand,
      if (saleStatus != null) 'sale_status': saleStatus,
      if (mobileNo != null) 'mobile_no': mobileNo,
      if (cnic != null) 'cnic': cnic,
      if (societyId != null) 'society_id': societyId,
      if (blockId != null) 'block_id': blockId,
      if (path != null) 'path': path,
      if (remarks != null) 'remarks': remarks,
      if (isActive != null) 'is_active': isActive,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FilesTableCompanion copyWith(
      {Value<String>? id,
      Value<String?>? companyId,
      Value<String?>? createdBy,
      Value<String>? name,
      Value<String?>? clientName,
      Value<String?>? fileNo,
      Value<String?>? referenceNo,
      Value<int?>? demand,
      Value<String?>? saleStatus,
      Value<String?>? mobileNo,
      Value<String?>? cnic,
      Value<String?>? societyId,
      Value<String?>? blockId,
      Value<String?>? path,
      Value<String?>? remarks,
      Value<bool>? isActive,
      Value<String>? updatedAt,
      Value<int>? rowid}) {
    return FilesTableCompanion(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      createdBy: createdBy ?? this.createdBy,
      name: name ?? this.name,
      clientName: clientName ?? this.clientName,
      fileNo: fileNo ?? this.fileNo,
      referenceNo: referenceNo ?? this.referenceNo,
      demand: demand ?? this.demand,
      saleStatus: saleStatus ?? this.saleStatus,
      mobileNo: mobileNo ?? this.mobileNo,
      cnic: cnic ?? this.cnic,
      societyId: societyId ?? this.societyId,
      blockId: blockId ?? this.blockId,
      path: path ?? this.path,
      remarks: remarks ?? this.remarks,
      isActive: isActive ?? this.isActive,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (clientName.present) {
      map['client_name'] = Variable<String>(clientName.value);
    }
    if (fileNo.present) {
      map['file_no'] = Variable<String>(fileNo.value);
    }
    if (referenceNo.present) {
      map['reference_no'] = Variable<String>(referenceNo.value);
    }
    if (demand.present) {
      map['demand'] = Variable<int>(demand.value);
    }
    if (saleStatus.present) {
      map['sale_status'] = Variable<String>(saleStatus.value);
    }
    if (mobileNo.present) {
      map['mobile_no'] = Variable<String>(mobileNo.value);
    }
    if (cnic.present) {
      map['cnic'] = Variable<String>(cnic.value);
    }
    if (societyId.present) {
      map['society_id'] = Variable<String>(societyId.value);
    }
    if (blockId.present) {
      map['block_id'] = Variable<String>(blockId.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (remarks.present) {
      map['remarks'] = Variable<String>(remarks.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FilesTableCompanion(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('createdBy: $createdBy, ')
          ..write('name: $name, ')
          ..write('clientName: $clientName, ')
          ..write('fileNo: $fileNo, ')
          ..write('referenceNo: $referenceNo, ')
          ..write('demand: $demand, ')
          ..write('saleStatus: $saleStatus, ')
          ..write('mobileNo: $mobileNo, ')
          ..write('cnic: $cnic, ')
          ..write('societyId: $societyId, ')
          ..write('blockId: $blockId, ')
          ..write('path: $path, ')
          ..write('remarks: $remarks, ')
          ..write('isActive: $isActive, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FileCommentsTable extends FileComments
    with TableInfo<$FileCommentsTable, FileComment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FileCommentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _parentIdMeta =
      const VerificationMeta('parentId');
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
      'parent_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES files_table (id)'));
  static const VerificationMeta _companyIdMeta =
      const VerificationMeta('companyId');
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
      'company_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _commentMeta =
      const VerificationMeta('comment');
  @override
  late final GeneratedColumn<String> comment = GeneratedColumn<String>(
      'comment', aliasedName, false,
      check: () => ComparableExpr(comment.length).isSmallerOrEqualValue(500),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, parentId, companyId, comment, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'file_comments';
  @override
  VerificationContext validateIntegrity(Insertable<FileComment> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(_parentIdMeta,
          parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta));
    } else if (isInserting) {
      context.missing(_parentIdMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(_companyIdMeta,
          companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta));
    }
    if (data.containsKey('comment')) {
      context.handle(_commentMeta,
          comment.isAcceptableOrUnknown(data['comment']!, _commentMeta));
    } else if (isInserting) {
      context.missing(_commentMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FileComment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FileComment(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      parentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}parent_id'])!,
      companyId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}company_id']),
      comment: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}comment'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $FileCommentsTable createAlias(String alias) {
    return $FileCommentsTable(attachedDatabase, alias);
  }
}

class FileComment extends DataClass implements Insertable<FileComment> {
  final String id;
  final String parentId;
  final String? companyId;
  final String comment;
  final String updatedAt;
  const FileComment(
      {required this.id,
      required this.parentId,
      this.companyId,
      required this.comment,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['parent_id'] = Variable<String>(parentId);
    if (!nullToAbsent || companyId != null) {
      map['company_id'] = Variable<String>(companyId);
    }
    map['comment'] = Variable<String>(comment);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  FileCommentsCompanion toCompanion(bool nullToAbsent) {
    return FileCommentsCompanion(
      id: Value(id),
      parentId: Value(parentId),
      companyId: companyId == null && nullToAbsent
          ? const Value.absent()
          : Value(companyId),
      comment: Value(comment),
      updatedAt: Value(updatedAt),
    );
  }

  factory FileComment.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FileComment(
      id: serializer.fromJson<String>(json['id']),
      parentId: serializer.fromJson<String>(json['parentId']),
      companyId: serializer.fromJson<String?>(json['companyId']),
      comment: serializer.fromJson<String>(json['comment']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'parentId': serializer.toJson<String>(parentId),
      'companyId': serializer.toJson<String?>(companyId),
      'comment': serializer.toJson<String>(comment),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  FileComment copyWith(
          {String? id,
          String? parentId,
          Value<String?> companyId = const Value.absent(),
          String? comment,
          String? updatedAt}) =>
      FileComment(
        id: id ?? this.id,
        parentId: parentId ?? this.parentId,
        companyId: companyId.present ? companyId.value : this.companyId,
        comment: comment ?? this.comment,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  FileComment copyWithCompanion(FileCommentsCompanion data) {
    return FileComment(
      id: data.id.present ? data.id.value : this.id,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      comment: data.comment.present ? data.comment.value : this.comment,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FileComment(')
          ..write('id: $id, ')
          ..write('parentId: $parentId, ')
          ..write('companyId: $companyId, ')
          ..write('comment: $comment, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, parentId, companyId, comment, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FileComment &&
          other.id == this.id &&
          other.parentId == this.parentId &&
          other.companyId == this.companyId &&
          other.comment == this.comment &&
          other.updatedAt == this.updatedAt);
}

class FileCommentsCompanion extends UpdateCompanion<FileComment> {
  final Value<String> id;
  final Value<String> parentId;
  final Value<String?> companyId;
  final Value<String> comment;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const FileCommentsCompanion({
    this.id = const Value.absent(),
    this.parentId = const Value.absent(),
    this.companyId = const Value.absent(),
    this.comment = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FileCommentsCompanion.insert({
    required String id,
    required String parentId,
    this.companyId = const Value.absent(),
    required String comment,
    required String updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        parentId = Value(parentId),
        comment = Value(comment),
        updatedAt = Value(updatedAt);
  static Insertable<FileComment> custom({
    Expression<String>? id,
    Expression<String>? parentId,
    Expression<String>? companyId,
    Expression<String>? comment,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (parentId != null) 'parent_id': parentId,
      if (companyId != null) 'company_id': companyId,
      if (comment != null) 'comment': comment,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FileCommentsCompanion copyWith(
      {Value<String>? id,
      Value<String>? parentId,
      Value<String?>? companyId,
      Value<String>? comment,
      Value<String>? updatedAt,
      Value<int>? rowid}) {
    return FileCommentsCompanion(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      companyId: companyId ?? this.companyId,
      comment: comment ?? this.comment,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (comment.present) {
      map['comment'] = Variable<String>(comment.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FileCommentsCompanion(')
          ..write('id: $id, ')
          ..write('parentId: $parentId, ')
          ..write('companyId: $companyId, ')
          ..write('comment: $comment, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RentalItemsTable extends RentalItems
    with TableInfo<$RentalItemsTable, RentalItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RentalItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _companyIdMeta =
      const VerificationMeta('companyId');
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
      'company_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdByMeta =
      const VerificationMeta('createdBy');
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
      'created_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<int> price = GeneratedColumn<int>(
      'price', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _remarksMeta =
      const VerificationMeta('remarks');
  @override
  late final GeneratedColumn<String> remarks = GeneratedColumn<String>(
      'remarks', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _locationMeta =
      const VerificationMeta('location');
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
      'location', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _ownerNameMeta =
      const VerificationMeta('ownerName');
  @override
  late final GeneratedColumn<String> ownerName = GeneratedColumn<String>(
      'owner_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _contactNoMeta =
      const VerificationMeta('contactNo');
  @override
  late final GeneratedColumn<String> contactNo = GeneratedColumn<String>(
      'contact_no', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cnicMeta = const VerificationMeta('cnic');
  @override
  late final GeneratedColumn<String> cnic = GeneratedColumn<String>(
      'cnic', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _securityMeta =
      const VerificationMeta('security');
  @override
  late final GeneratedColumn<int> security = GeneratedColumn<int>(
      'security', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _saleStatusMeta =
      const VerificationMeta('saleStatus');
  @override
  late final GeneratedColumn<String> saleStatus = GeneratedColumn<String>(
      'sale_status', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isActiveMeta =
      const VerificationMeta('isActive');
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
      'is_active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_active" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        companyId,
        createdBy,
        name,
        price,
        remarks,
        location,
        ownerName,
        contactNo,
        cnic,
        security,
        saleStatus,
        isActive,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rental_items';
  @override
  VerificationContext validateIntegrity(Insertable<RentalItem> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(_companyIdMeta,
          companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta));
    }
    if (data.containsKey('created_by')) {
      context.handle(_createdByMeta,
          createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('price')) {
      context.handle(
          _priceMeta, price.isAcceptableOrUnknown(data['price']!, _priceMeta));
    }
    if (data.containsKey('remarks')) {
      context.handle(_remarksMeta,
          remarks.isAcceptableOrUnknown(data['remarks']!, _remarksMeta));
    }
    if (data.containsKey('location')) {
      context.handle(_locationMeta,
          location.isAcceptableOrUnknown(data['location']!, _locationMeta));
    }
    if (data.containsKey('owner_name')) {
      context.handle(_ownerNameMeta,
          ownerName.isAcceptableOrUnknown(data['owner_name']!, _ownerNameMeta));
    }
    if (data.containsKey('contact_no')) {
      context.handle(_contactNoMeta,
          contactNo.isAcceptableOrUnknown(data['contact_no']!, _contactNoMeta));
    }
    if (data.containsKey('cnic')) {
      context.handle(
          _cnicMeta, cnic.isAcceptableOrUnknown(data['cnic']!, _cnicMeta));
    }
    if (data.containsKey('security')) {
      context.handle(_securityMeta,
          security.isAcceptableOrUnknown(data['security']!, _securityMeta));
    }
    if (data.containsKey('sale_status')) {
      context.handle(
          _saleStatusMeta,
          saleStatus.isAcceptableOrUnknown(
              data['sale_status']!, _saleStatusMeta));
    }
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RentalItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RentalItem(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      companyId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}company_id']),
      createdBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}created_by']),
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      price: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}price']),
      remarks: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}remarks']),
      location: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}location']),
      ownerName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}owner_name']),
      contactNo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}contact_no']),
      cnic: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cnic']),
      security: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}security']),
      saleStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sale_status']),
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $RentalItemsTable createAlias(String alias) {
    return $RentalItemsTable(attachedDatabase, alias);
  }
}

class RentalItem extends DataClass implements Insertable<RentalItem> {
  final String id;
  final String? companyId;
  final String? createdBy;
  final String name;
  final int? price;
  final String? remarks;
  final String? location;
  final String? ownerName;
  final String? contactNo;
  final String? cnic;
  final int? security;
  final String? saleStatus;
  final bool isActive;
  final String updatedAt;
  const RentalItem(
      {required this.id,
      this.companyId,
      this.createdBy,
      required this.name,
      this.price,
      this.remarks,
      this.location,
      this.ownerName,
      this.contactNo,
      this.cnic,
      this.security,
      this.saleStatus,
      required this.isActive,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || companyId != null) {
      map['company_id'] = Variable<String>(companyId);
    }
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<String>(createdBy);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || price != null) {
      map['price'] = Variable<int>(price);
    }
    if (!nullToAbsent || remarks != null) {
      map['remarks'] = Variable<String>(remarks);
    }
    if (!nullToAbsent || location != null) {
      map['location'] = Variable<String>(location);
    }
    if (!nullToAbsent || ownerName != null) {
      map['owner_name'] = Variable<String>(ownerName);
    }
    if (!nullToAbsent || contactNo != null) {
      map['contact_no'] = Variable<String>(contactNo);
    }
    if (!nullToAbsent || cnic != null) {
      map['cnic'] = Variable<String>(cnic);
    }
    if (!nullToAbsent || security != null) {
      map['security'] = Variable<int>(security);
    }
    if (!nullToAbsent || saleStatus != null) {
      map['sale_status'] = Variable<String>(saleStatus);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  RentalItemsCompanion toCompanion(bool nullToAbsent) {
    return RentalItemsCompanion(
      id: Value(id),
      companyId: companyId == null && nullToAbsent
          ? const Value.absent()
          : Value(companyId),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      name: Value(name),
      price:
          price == null && nullToAbsent ? const Value.absent() : Value(price),
      remarks: remarks == null && nullToAbsent
          ? const Value.absent()
          : Value(remarks),
      location: location == null && nullToAbsent
          ? const Value.absent()
          : Value(location),
      ownerName: ownerName == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerName),
      contactNo: contactNo == null && nullToAbsent
          ? const Value.absent()
          : Value(contactNo),
      cnic: cnic == null && nullToAbsent ? const Value.absent() : Value(cnic),
      security: security == null && nullToAbsent
          ? const Value.absent()
          : Value(security),
      saleStatus: saleStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(saleStatus),
      isActive: Value(isActive),
      updatedAt: Value(updatedAt),
    );
  }

  factory RentalItem.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RentalItem(
      id: serializer.fromJson<String>(json['id']),
      companyId: serializer.fromJson<String?>(json['companyId']),
      createdBy: serializer.fromJson<String?>(json['createdBy']),
      name: serializer.fromJson<String>(json['name']),
      price: serializer.fromJson<int?>(json['price']),
      remarks: serializer.fromJson<String?>(json['remarks']),
      location: serializer.fromJson<String?>(json['location']),
      ownerName: serializer.fromJson<String?>(json['ownerName']),
      contactNo: serializer.fromJson<String?>(json['contactNo']),
      cnic: serializer.fromJson<String?>(json['cnic']),
      security: serializer.fromJson<int?>(json['security']),
      saleStatus: serializer.fromJson<String?>(json['saleStatus']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'companyId': serializer.toJson<String?>(companyId),
      'createdBy': serializer.toJson<String?>(createdBy),
      'name': serializer.toJson<String>(name),
      'price': serializer.toJson<int?>(price),
      'remarks': serializer.toJson<String?>(remarks),
      'location': serializer.toJson<String?>(location),
      'ownerName': serializer.toJson<String?>(ownerName),
      'contactNo': serializer.toJson<String?>(contactNo),
      'cnic': serializer.toJson<String?>(cnic),
      'security': serializer.toJson<int?>(security),
      'saleStatus': serializer.toJson<String?>(saleStatus),
      'isActive': serializer.toJson<bool>(isActive),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  RentalItem copyWith(
          {String? id,
          Value<String?> companyId = const Value.absent(),
          Value<String?> createdBy = const Value.absent(),
          String? name,
          Value<int?> price = const Value.absent(),
          Value<String?> remarks = const Value.absent(),
          Value<String?> location = const Value.absent(),
          Value<String?> ownerName = const Value.absent(),
          Value<String?> contactNo = const Value.absent(),
          Value<String?> cnic = const Value.absent(),
          Value<int?> security = const Value.absent(),
          Value<String?> saleStatus = const Value.absent(),
          bool? isActive,
          String? updatedAt}) =>
      RentalItem(
        id: id ?? this.id,
        companyId: companyId.present ? companyId.value : this.companyId,
        createdBy: createdBy.present ? createdBy.value : this.createdBy,
        name: name ?? this.name,
        price: price.present ? price.value : this.price,
        remarks: remarks.present ? remarks.value : this.remarks,
        location: location.present ? location.value : this.location,
        ownerName: ownerName.present ? ownerName.value : this.ownerName,
        contactNo: contactNo.present ? contactNo.value : this.contactNo,
        cnic: cnic.present ? cnic.value : this.cnic,
        security: security.present ? security.value : this.security,
        saleStatus: saleStatus.present ? saleStatus.value : this.saleStatus,
        isActive: isActive ?? this.isActive,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  RentalItem copyWithCompanion(RentalItemsCompanion data) {
    return RentalItem(
      id: data.id.present ? data.id.value : this.id,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      name: data.name.present ? data.name.value : this.name,
      price: data.price.present ? data.price.value : this.price,
      remarks: data.remarks.present ? data.remarks.value : this.remarks,
      location: data.location.present ? data.location.value : this.location,
      ownerName: data.ownerName.present ? data.ownerName.value : this.ownerName,
      contactNo: data.contactNo.present ? data.contactNo.value : this.contactNo,
      cnic: data.cnic.present ? data.cnic.value : this.cnic,
      security: data.security.present ? data.security.value : this.security,
      saleStatus:
          data.saleStatus.present ? data.saleStatus.value : this.saleStatus,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RentalItem(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('createdBy: $createdBy, ')
          ..write('name: $name, ')
          ..write('price: $price, ')
          ..write('remarks: $remarks, ')
          ..write('location: $location, ')
          ..write('ownerName: $ownerName, ')
          ..write('contactNo: $contactNo, ')
          ..write('cnic: $cnic, ')
          ..write('security: $security, ')
          ..write('saleStatus: $saleStatus, ')
          ..write('isActive: $isActive, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      companyId,
      createdBy,
      name,
      price,
      remarks,
      location,
      ownerName,
      contactNo,
      cnic,
      security,
      saleStatus,
      isActive,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RentalItem &&
          other.id == this.id &&
          other.companyId == this.companyId &&
          other.createdBy == this.createdBy &&
          other.name == this.name &&
          other.price == this.price &&
          other.remarks == this.remarks &&
          other.location == this.location &&
          other.ownerName == this.ownerName &&
          other.contactNo == this.contactNo &&
          other.cnic == this.cnic &&
          other.security == this.security &&
          other.saleStatus == this.saleStatus &&
          other.isActive == this.isActive &&
          other.updatedAt == this.updatedAt);
}

class RentalItemsCompanion extends UpdateCompanion<RentalItem> {
  final Value<String> id;
  final Value<String?> companyId;
  final Value<String?> createdBy;
  final Value<String> name;
  final Value<int?> price;
  final Value<String?> remarks;
  final Value<String?> location;
  final Value<String?> ownerName;
  final Value<String?> contactNo;
  final Value<String?> cnic;
  final Value<int?> security;
  final Value<String?> saleStatus;
  final Value<bool> isActive;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const RentalItemsCompanion({
    this.id = const Value.absent(),
    this.companyId = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.name = const Value.absent(),
    this.price = const Value.absent(),
    this.remarks = const Value.absent(),
    this.location = const Value.absent(),
    this.ownerName = const Value.absent(),
    this.contactNo = const Value.absent(),
    this.cnic = const Value.absent(),
    this.security = const Value.absent(),
    this.saleStatus = const Value.absent(),
    this.isActive = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RentalItemsCompanion.insert({
    required String id,
    this.companyId = const Value.absent(),
    this.createdBy = const Value.absent(),
    required String name,
    this.price = const Value.absent(),
    this.remarks = const Value.absent(),
    this.location = const Value.absent(),
    this.ownerName = const Value.absent(),
    this.contactNo = const Value.absent(),
    this.cnic = const Value.absent(),
    this.security = const Value.absent(),
    this.saleStatus = const Value.absent(),
    this.isActive = const Value.absent(),
    required String updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        updatedAt = Value(updatedAt);
  static Insertable<RentalItem> custom({
    Expression<String>? id,
    Expression<String>? companyId,
    Expression<String>? createdBy,
    Expression<String>? name,
    Expression<int>? price,
    Expression<String>? remarks,
    Expression<String>? location,
    Expression<String>? ownerName,
    Expression<String>? contactNo,
    Expression<String>? cnic,
    Expression<int>? security,
    Expression<String>? saleStatus,
    Expression<bool>? isActive,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (companyId != null) 'company_id': companyId,
      if (createdBy != null) 'created_by': createdBy,
      if (name != null) 'name': name,
      if (price != null) 'price': price,
      if (remarks != null) 'remarks': remarks,
      if (location != null) 'location': location,
      if (ownerName != null) 'owner_name': ownerName,
      if (contactNo != null) 'contact_no': contactNo,
      if (cnic != null) 'cnic': cnic,
      if (security != null) 'security': security,
      if (saleStatus != null) 'sale_status': saleStatus,
      if (isActive != null) 'is_active': isActive,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RentalItemsCompanion copyWith(
      {Value<String>? id,
      Value<String?>? companyId,
      Value<String?>? createdBy,
      Value<String>? name,
      Value<int?>? price,
      Value<String?>? remarks,
      Value<String?>? location,
      Value<String?>? ownerName,
      Value<String?>? contactNo,
      Value<String?>? cnic,
      Value<int?>? security,
      Value<String?>? saleStatus,
      Value<bool>? isActive,
      Value<String>? updatedAt,
      Value<int>? rowid}) {
    return RentalItemsCompanion(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      createdBy: createdBy ?? this.createdBy,
      name: name ?? this.name,
      price: price ?? this.price,
      remarks: remarks ?? this.remarks,
      location: location ?? this.location,
      ownerName: ownerName ?? this.ownerName,
      contactNo: contactNo ?? this.contactNo,
      cnic: cnic ?? this.cnic,
      security: security ?? this.security,
      saleStatus: saleStatus ?? this.saleStatus,
      isActive: isActive ?? this.isActive,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (price.present) {
      map['price'] = Variable<int>(price.value);
    }
    if (remarks.present) {
      map['remarks'] = Variable<String>(remarks.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (ownerName.present) {
      map['owner_name'] = Variable<String>(ownerName.value);
    }
    if (contactNo.present) {
      map['contact_no'] = Variable<String>(contactNo.value);
    }
    if (cnic.present) {
      map['cnic'] = Variable<String>(cnic.value);
    }
    if (security.present) {
      map['security'] = Variable<int>(security.value);
    }
    if (saleStatus.present) {
      map['sale_status'] = Variable<String>(saleStatus.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RentalItemsCompanion(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('createdBy: $createdBy, ')
          ..write('name: $name, ')
          ..write('price: $price, ')
          ..write('remarks: $remarks, ')
          ..write('location: $location, ')
          ..write('ownerName: $ownerName, ')
          ..write('contactNo: $contactNo, ')
          ..write('cnic: $cnic, ')
          ..write('security: $security, ')
          ..write('saleStatus: $saleStatus, ')
          ..write('isActive: $isActive, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RentalCommentsTable extends RentalComments
    with TableInfo<$RentalCommentsTable, RentalComment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RentalCommentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _parentIdMeta =
      const VerificationMeta('parentId');
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
      'parent_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES rental_items (id)'));
  static const VerificationMeta _companyIdMeta =
      const VerificationMeta('companyId');
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
      'company_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _commentMeta =
      const VerificationMeta('comment');
  @override
  late final GeneratedColumn<String> comment = GeneratedColumn<String>(
      'comment', aliasedName, false,
      check: () => ComparableExpr(comment.length).isSmallerOrEqualValue(500),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, parentId, companyId, comment, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rental_comments';
  @override
  VerificationContext validateIntegrity(Insertable<RentalComment> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(_parentIdMeta,
          parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta));
    } else if (isInserting) {
      context.missing(_parentIdMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(_companyIdMeta,
          companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta));
    }
    if (data.containsKey('comment')) {
      context.handle(_commentMeta,
          comment.isAcceptableOrUnknown(data['comment']!, _commentMeta));
    } else if (isInserting) {
      context.missing(_commentMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RentalComment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RentalComment(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      parentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}parent_id'])!,
      companyId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}company_id']),
      comment: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}comment'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $RentalCommentsTable createAlias(String alias) {
    return $RentalCommentsTable(attachedDatabase, alias);
  }
}

class RentalComment extends DataClass implements Insertable<RentalComment> {
  final String id;
  final String parentId;
  final String? companyId;
  final String comment;
  final String updatedAt;
  const RentalComment(
      {required this.id,
      required this.parentId,
      this.companyId,
      required this.comment,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['parent_id'] = Variable<String>(parentId);
    if (!nullToAbsent || companyId != null) {
      map['company_id'] = Variable<String>(companyId);
    }
    map['comment'] = Variable<String>(comment);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  RentalCommentsCompanion toCompanion(bool nullToAbsent) {
    return RentalCommentsCompanion(
      id: Value(id),
      parentId: Value(parentId),
      companyId: companyId == null && nullToAbsent
          ? const Value.absent()
          : Value(companyId),
      comment: Value(comment),
      updatedAt: Value(updatedAt),
    );
  }

  factory RentalComment.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RentalComment(
      id: serializer.fromJson<String>(json['id']),
      parentId: serializer.fromJson<String>(json['parentId']),
      companyId: serializer.fromJson<String?>(json['companyId']),
      comment: serializer.fromJson<String>(json['comment']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'parentId': serializer.toJson<String>(parentId),
      'companyId': serializer.toJson<String?>(companyId),
      'comment': serializer.toJson<String>(comment),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  RentalComment copyWith(
          {String? id,
          String? parentId,
          Value<String?> companyId = const Value.absent(),
          String? comment,
          String? updatedAt}) =>
      RentalComment(
        id: id ?? this.id,
        parentId: parentId ?? this.parentId,
        companyId: companyId.present ? companyId.value : this.companyId,
        comment: comment ?? this.comment,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  RentalComment copyWithCompanion(RentalCommentsCompanion data) {
    return RentalComment(
      id: data.id.present ? data.id.value : this.id,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      comment: data.comment.present ? data.comment.value : this.comment,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RentalComment(')
          ..write('id: $id, ')
          ..write('parentId: $parentId, ')
          ..write('companyId: $companyId, ')
          ..write('comment: $comment, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, parentId, companyId, comment, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RentalComment &&
          other.id == this.id &&
          other.parentId == this.parentId &&
          other.companyId == this.companyId &&
          other.comment == this.comment &&
          other.updatedAt == this.updatedAt);
}

class RentalCommentsCompanion extends UpdateCompanion<RentalComment> {
  final Value<String> id;
  final Value<String> parentId;
  final Value<String?> companyId;
  final Value<String> comment;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const RentalCommentsCompanion({
    this.id = const Value.absent(),
    this.parentId = const Value.absent(),
    this.companyId = const Value.absent(),
    this.comment = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RentalCommentsCompanion.insert({
    required String id,
    required String parentId,
    this.companyId = const Value.absent(),
    required String comment,
    required String updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        parentId = Value(parentId),
        comment = Value(comment),
        updatedAt = Value(updatedAt);
  static Insertable<RentalComment> custom({
    Expression<String>? id,
    Expression<String>? parentId,
    Expression<String>? companyId,
    Expression<String>? comment,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (parentId != null) 'parent_id': parentId,
      if (companyId != null) 'company_id': companyId,
      if (comment != null) 'comment': comment,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RentalCommentsCompanion copyWith(
      {Value<String>? id,
      Value<String>? parentId,
      Value<String?>? companyId,
      Value<String>? comment,
      Value<String>? updatedAt,
      Value<int>? rowid}) {
    return RentalCommentsCompanion(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      companyId: companyId ?? this.companyId,
      comment: comment ?? this.comment,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (comment.present) {
      map['comment'] = Variable<String>(comment.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RentalCommentsCompanion(')
          ..write('id: $id, ')
          ..write('parentId: $parentId, ')
          ..write('companyId: $companyId, ')
          ..write('comment: $comment, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkingProgressTable extends WorkingProgress
    with TableInfo<$WorkingProgressTable, WorkingProgressData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkingProgressTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _companyIdMeta =
      const VerificationMeta('companyId');
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
      'company_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _remarksMeta =
      const VerificationMeta('remarks');
  @override
  late final GeneratedColumn<String> remarks = GeneratedColumn<String>(
      'remarks', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _fromUserMeta =
      const VerificationMeta('fromUser');
  @override
  late final GeneratedColumn<String> fromUser = GeneratedColumn<String>(
      'from_user', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _toUserMeta = const VerificationMeta('toUser');
  @override
  late final GeneratedColumn<String> toUser = GeneratedColumn<String>(
      'to_user', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _transferDateMeta =
      const VerificationMeta('transferDate');
  @override
  late final GeneratedColumn<String> transferDate = GeneratedColumn<String>(
      'transfer_date', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _nextWorkingDateMeta =
      const VerificationMeta('nextWorkingDate');
  @override
  late final GeneratedColumn<String> nextWorkingDate = GeneratedColumn<String>(
      'next_working_date', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isActiveMeta =
      const VerificationMeta('isActive');
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
      'is_active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_active" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        companyId,
        name,
        status,
        remarks,
        fromUser,
        toUser,
        transferDate,
        nextWorkingDate,
        category,
        isActive,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'working_progress';
  @override
  VerificationContext validateIntegrity(
      Insertable<WorkingProgressData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(_companyIdMeta,
          companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('remarks')) {
      context.handle(_remarksMeta,
          remarks.isAcceptableOrUnknown(data['remarks']!, _remarksMeta));
    }
    if (data.containsKey('from_user')) {
      context.handle(_fromUserMeta,
          fromUser.isAcceptableOrUnknown(data['from_user']!, _fromUserMeta));
    }
    if (data.containsKey('to_user')) {
      context.handle(_toUserMeta,
          toUser.isAcceptableOrUnknown(data['to_user']!, _toUserMeta));
    }
    if (data.containsKey('transfer_date')) {
      context.handle(
          _transferDateMeta,
          transferDate.isAcceptableOrUnknown(
              data['transfer_date']!, _transferDateMeta));
    }
    if (data.containsKey('next_working_date')) {
      context.handle(
          _nextWorkingDateMeta,
          nextWorkingDate.isAcceptableOrUnknown(
              data['next_working_date']!, _nextWorkingDateMeta));
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    }
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkingProgressData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkingProgressData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      companyId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}company_id']),
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status']),
      remarks: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}remarks']),
      fromUser: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}from_user']),
      toUser: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}to_user']),
      transferDate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}transfer_date']),
      nextWorkingDate: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}next_working_date']),
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category']),
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $WorkingProgressTable createAlias(String alias) {
    return $WorkingProgressTable(attachedDatabase, alias);
  }
}

class WorkingProgressData extends DataClass
    implements Insertable<WorkingProgressData> {
  final String id;
  final String? companyId;
  final String name;
  final String? status;
  final String? remarks;
  final String? fromUser;
  final String? toUser;
  final String? transferDate;
  final String? nextWorkingDate;
  final String? category;
  final bool isActive;
  final String updatedAt;
  const WorkingProgressData(
      {required this.id,
      this.companyId,
      required this.name,
      this.status,
      this.remarks,
      this.fromUser,
      this.toUser,
      this.transferDate,
      this.nextWorkingDate,
      this.category,
      required this.isActive,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || companyId != null) {
      map['company_id'] = Variable<String>(companyId);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || status != null) {
      map['status'] = Variable<String>(status);
    }
    if (!nullToAbsent || remarks != null) {
      map['remarks'] = Variable<String>(remarks);
    }
    if (!nullToAbsent || fromUser != null) {
      map['from_user'] = Variable<String>(fromUser);
    }
    if (!nullToAbsent || toUser != null) {
      map['to_user'] = Variable<String>(toUser);
    }
    if (!nullToAbsent || transferDate != null) {
      map['transfer_date'] = Variable<String>(transferDate);
    }
    if (!nullToAbsent || nextWorkingDate != null) {
      map['next_working_date'] = Variable<String>(nextWorkingDate);
    }
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  WorkingProgressCompanion toCompanion(bool nullToAbsent) {
    return WorkingProgressCompanion(
      id: Value(id),
      companyId: companyId == null && nullToAbsent
          ? const Value.absent()
          : Value(companyId),
      name: Value(name),
      status:
          status == null && nullToAbsent ? const Value.absent() : Value(status),
      remarks: remarks == null && nullToAbsent
          ? const Value.absent()
          : Value(remarks),
      fromUser: fromUser == null && nullToAbsent
          ? const Value.absent()
          : Value(fromUser),
      toUser:
          toUser == null && nullToAbsent ? const Value.absent() : Value(toUser),
      transferDate: transferDate == null && nullToAbsent
          ? const Value.absent()
          : Value(transferDate),
      nextWorkingDate: nextWorkingDate == null && nullToAbsent
          ? const Value.absent()
          : Value(nextWorkingDate),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      isActive: Value(isActive),
      updatedAt: Value(updatedAt),
    );
  }

  factory WorkingProgressData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkingProgressData(
      id: serializer.fromJson<String>(json['id']),
      companyId: serializer.fromJson<String?>(json['companyId']),
      name: serializer.fromJson<String>(json['name']),
      status: serializer.fromJson<String?>(json['status']),
      remarks: serializer.fromJson<String?>(json['remarks']),
      fromUser: serializer.fromJson<String?>(json['fromUser']),
      toUser: serializer.fromJson<String?>(json['toUser']),
      transferDate: serializer.fromJson<String?>(json['transferDate']),
      nextWorkingDate: serializer.fromJson<String?>(json['nextWorkingDate']),
      category: serializer.fromJson<String?>(json['category']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'companyId': serializer.toJson<String?>(companyId),
      'name': serializer.toJson<String>(name),
      'status': serializer.toJson<String?>(status),
      'remarks': serializer.toJson<String?>(remarks),
      'fromUser': serializer.toJson<String?>(fromUser),
      'toUser': serializer.toJson<String?>(toUser),
      'transferDate': serializer.toJson<String?>(transferDate),
      'nextWorkingDate': serializer.toJson<String?>(nextWorkingDate),
      'category': serializer.toJson<String?>(category),
      'isActive': serializer.toJson<bool>(isActive),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  WorkingProgressData copyWith(
          {String? id,
          Value<String?> companyId = const Value.absent(),
          String? name,
          Value<String?> status = const Value.absent(),
          Value<String?> remarks = const Value.absent(),
          Value<String?> fromUser = const Value.absent(),
          Value<String?> toUser = const Value.absent(),
          Value<String?> transferDate = const Value.absent(),
          Value<String?> nextWorkingDate = const Value.absent(),
          Value<String?> category = const Value.absent(),
          bool? isActive,
          String? updatedAt}) =>
      WorkingProgressData(
        id: id ?? this.id,
        companyId: companyId.present ? companyId.value : this.companyId,
        name: name ?? this.name,
        status: status.present ? status.value : this.status,
        remarks: remarks.present ? remarks.value : this.remarks,
        fromUser: fromUser.present ? fromUser.value : this.fromUser,
        toUser: toUser.present ? toUser.value : this.toUser,
        transferDate:
            transferDate.present ? transferDate.value : this.transferDate,
        nextWorkingDate: nextWorkingDate.present
            ? nextWorkingDate.value
            : this.nextWorkingDate,
        category: category.present ? category.value : this.category,
        isActive: isActive ?? this.isActive,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  WorkingProgressData copyWithCompanion(WorkingProgressCompanion data) {
    return WorkingProgressData(
      id: data.id.present ? data.id.value : this.id,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      name: data.name.present ? data.name.value : this.name,
      status: data.status.present ? data.status.value : this.status,
      remarks: data.remarks.present ? data.remarks.value : this.remarks,
      fromUser: data.fromUser.present ? data.fromUser.value : this.fromUser,
      toUser: data.toUser.present ? data.toUser.value : this.toUser,
      transferDate: data.transferDate.present
          ? data.transferDate.value
          : this.transferDate,
      nextWorkingDate: data.nextWorkingDate.present
          ? data.nextWorkingDate.value
          : this.nextWorkingDate,
      category: data.category.present ? data.category.value : this.category,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkingProgressData(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('name: $name, ')
          ..write('status: $status, ')
          ..write('remarks: $remarks, ')
          ..write('fromUser: $fromUser, ')
          ..write('toUser: $toUser, ')
          ..write('transferDate: $transferDate, ')
          ..write('nextWorkingDate: $nextWorkingDate, ')
          ..write('category: $category, ')
          ..write('isActive: $isActive, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      companyId,
      name,
      status,
      remarks,
      fromUser,
      toUser,
      transferDate,
      nextWorkingDate,
      category,
      isActive,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkingProgressData &&
          other.id == this.id &&
          other.companyId == this.companyId &&
          other.name == this.name &&
          other.status == this.status &&
          other.remarks == this.remarks &&
          other.fromUser == this.fromUser &&
          other.toUser == this.toUser &&
          other.transferDate == this.transferDate &&
          other.nextWorkingDate == this.nextWorkingDate &&
          other.category == this.category &&
          other.isActive == this.isActive &&
          other.updatedAt == this.updatedAt);
}

class WorkingProgressCompanion extends UpdateCompanion<WorkingProgressData> {
  final Value<String> id;
  final Value<String?> companyId;
  final Value<String> name;
  final Value<String?> status;
  final Value<String?> remarks;
  final Value<String?> fromUser;
  final Value<String?> toUser;
  final Value<String?> transferDate;
  final Value<String?> nextWorkingDate;
  final Value<String?> category;
  final Value<bool> isActive;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const WorkingProgressCompanion({
    this.id = const Value.absent(),
    this.companyId = const Value.absent(),
    this.name = const Value.absent(),
    this.status = const Value.absent(),
    this.remarks = const Value.absent(),
    this.fromUser = const Value.absent(),
    this.toUser = const Value.absent(),
    this.transferDate = const Value.absent(),
    this.nextWorkingDate = const Value.absent(),
    this.category = const Value.absent(),
    this.isActive = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkingProgressCompanion.insert({
    required String id,
    this.companyId = const Value.absent(),
    required String name,
    this.status = const Value.absent(),
    this.remarks = const Value.absent(),
    this.fromUser = const Value.absent(),
    this.toUser = const Value.absent(),
    this.transferDate = const Value.absent(),
    this.nextWorkingDate = const Value.absent(),
    this.category = const Value.absent(),
    this.isActive = const Value.absent(),
    required String updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        updatedAt = Value(updatedAt);
  static Insertable<WorkingProgressData> custom({
    Expression<String>? id,
    Expression<String>? companyId,
    Expression<String>? name,
    Expression<String>? status,
    Expression<String>? remarks,
    Expression<String>? fromUser,
    Expression<String>? toUser,
    Expression<String>? transferDate,
    Expression<String>? nextWorkingDate,
    Expression<String>? category,
    Expression<bool>? isActive,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (companyId != null) 'company_id': companyId,
      if (name != null) 'name': name,
      if (status != null) 'status': status,
      if (remarks != null) 'remarks': remarks,
      if (fromUser != null) 'from_user': fromUser,
      if (toUser != null) 'to_user': toUser,
      if (transferDate != null) 'transfer_date': transferDate,
      if (nextWorkingDate != null) 'next_working_date': nextWorkingDate,
      if (category != null) 'category': category,
      if (isActive != null) 'is_active': isActive,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkingProgressCompanion copyWith(
      {Value<String>? id,
      Value<String?>? companyId,
      Value<String>? name,
      Value<String?>? status,
      Value<String?>? remarks,
      Value<String?>? fromUser,
      Value<String?>? toUser,
      Value<String?>? transferDate,
      Value<String?>? nextWorkingDate,
      Value<String?>? category,
      Value<bool>? isActive,
      Value<String>? updatedAt,
      Value<int>? rowid}) {
    return WorkingProgressCompanion(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
      fromUser: fromUser ?? this.fromUser,
      toUser: toUser ?? this.toUser,
      transferDate: transferDate ?? this.transferDate,
      nextWorkingDate: nextWorkingDate ?? this.nextWorkingDate,
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (remarks.present) {
      map['remarks'] = Variable<String>(remarks.value);
    }
    if (fromUser.present) {
      map['from_user'] = Variable<String>(fromUser.value);
    }
    if (toUser.present) {
      map['to_user'] = Variable<String>(toUser.value);
    }
    if (transferDate.present) {
      map['transfer_date'] = Variable<String>(transferDate.value);
    }
    if (nextWorkingDate.present) {
      map['next_working_date'] = Variable<String>(nextWorkingDate.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkingProgressCompanion(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('name: $name, ')
          ..write('status: $status, ')
          ..write('remarks: $remarks, ')
          ..write('fromUser: $fromUser, ')
          ..write('toUser: $toUser, ')
          ..write('transferDate: $transferDate, ')
          ..write('nextWorkingDate: $nextWorkingDate, ')
          ..write('category: $category, ')
          ..write('isActive: $isActive, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkingCommentsTable extends WorkingComments
    with TableInfo<$WorkingCommentsTable, WorkingComment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkingCommentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _parentIdMeta =
      const VerificationMeta('parentId');
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
      'parent_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES working_progress (id)'));
  static const VerificationMeta _companyIdMeta =
      const VerificationMeta('companyId');
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
      'company_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _commentMeta =
      const VerificationMeta('comment');
  @override
  late final GeneratedColumn<String> comment = GeneratedColumn<String>(
      'comment', aliasedName, false,
      check: () => ComparableExpr(comment.length).isSmallerOrEqualValue(500),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, parentId, companyId, comment, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'working_comments';
  @override
  VerificationContext validateIntegrity(Insertable<WorkingComment> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(_parentIdMeta,
          parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta));
    } else if (isInserting) {
      context.missing(_parentIdMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(_companyIdMeta,
          companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta));
    }
    if (data.containsKey('comment')) {
      context.handle(_commentMeta,
          comment.isAcceptableOrUnknown(data['comment']!, _commentMeta));
    } else if (isInserting) {
      context.missing(_commentMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkingComment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkingComment(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      parentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}parent_id'])!,
      companyId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}company_id']),
      comment: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}comment'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $WorkingCommentsTable createAlias(String alias) {
    return $WorkingCommentsTable(attachedDatabase, alias);
  }
}

class WorkingComment extends DataClass implements Insertable<WorkingComment> {
  final String id;
  final String parentId;
  final String? companyId;
  final String comment;
  final String updatedAt;
  const WorkingComment(
      {required this.id,
      required this.parentId,
      this.companyId,
      required this.comment,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['parent_id'] = Variable<String>(parentId);
    if (!nullToAbsent || companyId != null) {
      map['company_id'] = Variable<String>(companyId);
    }
    map['comment'] = Variable<String>(comment);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  WorkingCommentsCompanion toCompanion(bool nullToAbsent) {
    return WorkingCommentsCompanion(
      id: Value(id),
      parentId: Value(parentId),
      companyId: companyId == null && nullToAbsent
          ? const Value.absent()
          : Value(companyId),
      comment: Value(comment),
      updatedAt: Value(updatedAt),
    );
  }

  factory WorkingComment.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkingComment(
      id: serializer.fromJson<String>(json['id']),
      parentId: serializer.fromJson<String>(json['parentId']),
      companyId: serializer.fromJson<String?>(json['companyId']),
      comment: serializer.fromJson<String>(json['comment']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'parentId': serializer.toJson<String>(parentId),
      'companyId': serializer.toJson<String?>(companyId),
      'comment': serializer.toJson<String>(comment),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  WorkingComment copyWith(
          {String? id,
          String? parentId,
          Value<String?> companyId = const Value.absent(),
          String? comment,
          String? updatedAt}) =>
      WorkingComment(
        id: id ?? this.id,
        parentId: parentId ?? this.parentId,
        companyId: companyId.present ? companyId.value : this.companyId,
        comment: comment ?? this.comment,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  WorkingComment copyWithCompanion(WorkingCommentsCompanion data) {
    return WorkingComment(
      id: data.id.present ? data.id.value : this.id,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      comment: data.comment.present ? data.comment.value : this.comment,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkingComment(')
          ..write('id: $id, ')
          ..write('parentId: $parentId, ')
          ..write('companyId: $companyId, ')
          ..write('comment: $comment, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, parentId, companyId, comment, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkingComment &&
          other.id == this.id &&
          other.parentId == this.parentId &&
          other.companyId == this.companyId &&
          other.comment == this.comment &&
          other.updatedAt == this.updatedAt);
}

class WorkingCommentsCompanion extends UpdateCompanion<WorkingComment> {
  final Value<String> id;
  final Value<String> parentId;
  final Value<String?> companyId;
  final Value<String> comment;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const WorkingCommentsCompanion({
    this.id = const Value.absent(),
    this.parentId = const Value.absent(),
    this.companyId = const Value.absent(),
    this.comment = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkingCommentsCompanion.insert({
    required String id,
    required String parentId,
    this.companyId = const Value.absent(),
    required String comment,
    required String updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        parentId = Value(parentId),
        comment = Value(comment),
        updatedAt = Value(updatedAt);
  static Insertable<WorkingComment> custom({
    Expression<String>? id,
    Expression<String>? parentId,
    Expression<String>? companyId,
    Expression<String>? comment,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (parentId != null) 'parent_id': parentId,
      if (companyId != null) 'company_id': companyId,
      if (comment != null) 'comment': comment,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkingCommentsCompanion copyWith(
      {Value<String>? id,
      Value<String>? parentId,
      Value<String?>? companyId,
      Value<String>? comment,
      Value<String>? updatedAt,
      Value<int>? rowid}) {
    return WorkingCommentsCompanion(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      companyId: companyId ?? this.companyId,
      comment: comment ?? this.comment,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (comment.present) {
      map['comment'] = Variable<String>(comment.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkingCommentsCompanion(')
          ..write('id: $id, ')
          ..write('parentId: $parentId, ')
          ..write('companyId: $companyId, ')
          ..write('comment: $comment, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RemindersTable extends Reminders
    with TableInfo<$RemindersTable, Reminder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RemindersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _reminderIdMeta =
      const VerificationMeta('reminderId');
  @override
  late final GeneratedColumn<int> reminderId = GeneratedColumn<int>(
      'reminder_id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _agentIdMeta =
      const VerificationMeta('agentId');
  @override
  late final GeneratedColumn<String> agentId = GeneratedColumn<String>(
      'agent_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES users (id)'));
  static const VerificationMeta _companyIdMeta =
      const VerificationMeta('companyId');
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
      'company_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _clientNameMeta =
      const VerificationMeta('clientName');
  @override
  late final GeneratedColumn<String> clientName = GeneratedColumn<String>(
      'client_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _clientPhoneMeta =
      const VerificationMeta('clientPhone');
  @override
  late final GeneratedColumn<String> clientPhone = GeneratedColumn<String>(
      'client_phone', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _reminderTitleMeta =
      const VerificationMeta('reminderTitle');
  @override
  late final GeneratedColumn<String> reminderTitle = GeneratedColumn<String>(
      'reminder_title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _reminderDetailsMeta =
      const VerificationMeta('reminderDetails');
  @override
  late final GeneratedColumn<String> reminderDetails = GeneratedColumn<String>(
      'reminder_details', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _reminderDateMeta =
      const VerificationMeta('reminderDate');
  @override
  late final GeneratedColumn<String> reminderDate = GeneratedColumn<String>(
      'reminder_date', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _reminderTimeMeta =
      const VerificationMeta('reminderTime');
  @override
  late final GeneratedColumn<String> reminderTime = GeneratedColumn<String>(
      'reminder_time', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _notificationStatusMeta =
      const VerificationMeta('notificationStatus');
  @override
  late final GeneratedColumn<String> notificationStatus =
      GeneratedColumn<String>('notification_status', aliasedName, false,
          type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _isActiveMeta =
      const VerificationMeta('isActive');
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
      'is_active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_active" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
      'created_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        reminderId,
        agentId,
        companyId,
        clientName,
        clientPhone,
        reminderTitle,
        reminderDetails,
        reminderDate,
        reminderTime,
        notificationStatus,
        isActive,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reminders';
  @override
  VerificationContext validateIntegrity(Insertable<Reminder> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('reminder_id')) {
      context.handle(
          _reminderIdMeta,
          reminderId.isAcceptableOrUnknown(
              data['reminder_id']!, _reminderIdMeta));
    }
    if (data.containsKey('agent_id')) {
      context.handle(_agentIdMeta,
          agentId.isAcceptableOrUnknown(data['agent_id']!, _agentIdMeta));
    } else if (isInserting) {
      context.missing(_agentIdMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(_companyIdMeta,
          companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta));
    }
    if (data.containsKey('client_name')) {
      context.handle(
          _clientNameMeta,
          clientName.isAcceptableOrUnknown(
              data['client_name']!, _clientNameMeta));
    }
    if (data.containsKey('client_phone')) {
      context.handle(
          _clientPhoneMeta,
          clientPhone.isAcceptableOrUnknown(
              data['client_phone']!, _clientPhoneMeta));
    }
    if (data.containsKey('reminder_title')) {
      context.handle(
          _reminderTitleMeta,
          reminderTitle.isAcceptableOrUnknown(
              data['reminder_title']!, _reminderTitleMeta));
    } else if (isInserting) {
      context.missing(_reminderTitleMeta);
    }
    if (data.containsKey('reminder_details')) {
      context.handle(
          _reminderDetailsMeta,
          reminderDetails.isAcceptableOrUnknown(
              data['reminder_details']!, _reminderDetailsMeta));
    }
    if (data.containsKey('reminder_date')) {
      context.handle(
          _reminderDateMeta,
          reminderDate.isAcceptableOrUnknown(
              data['reminder_date']!, _reminderDateMeta));
    } else if (isInserting) {
      context.missing(_reminderDateMeta);
    }
    if (data.containsKey('reminder_time')) {
      context.handle(
          _reminderTimeMeta,
          reminderTime.isAcceptableOrUnknown(
              data['reminder_time']!, _reminderTimeMeta));
    } else if (isInserting) {
      context.missing(_reminderTimeMeta);
    }
    if (data.containsKey('notification_status')) {
      context.handle(
          _notificationStatusMeta,
          notificationStatus.isAcceptableOrUnknown(
              data['notification_status']!, _notificationStatusMeta));
    } else if (isInserting) {
      context.missing(_notificationStatusMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {reminderId};
  @override
  Reminder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Reminder(
      reminderId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}reminder_id'])!,
      agentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}agent_id'])!,
      companyId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}company_id']),
      clientName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}client_name']),
      clientPhone: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}client_phone']),
      reminderTitle: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reminder_title'])!,
      reminderDetails: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}reminder_details']),
      reminderDate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reminder_date'])!,
      reminderTime: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reminder_time'])!,
      notificationStatus: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}notification_status'])!,
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $RemindersTable createAlias(String alias) {
    return $RemindersTable(attachedDatabase, alias);
  }
}

class Reminder extends DataClass implements Insertable<Reminder> {
  final int reminderId;
  final String agentId;
  final String? companyId;
  final String? clientName;
  final String? clientPhone;
  final String reminderTitle;
  final String? reminderDetails;
  final String reminderDate;
  final String reminderTime;
  final String notificationStatus;
  final bool isActive;
  final String createdAt;
  final String updatedAt;
  const Reminder(
      {required this.reminderId,
      required this.agentId,
      this.companyId,
      this.clientName,
      this.clientPhone,
      required this.reminderTitle,
      this.reminderDetails,
      required this.reminderDate,
      required this.reminderTime,
      required this.notificationStatus,
      required this.isActive,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['reminder_id'] = Variable<int>(reminderId);
    map['agent_id'] = Variable<String>(agentId);
    if (!nullToAbsent || companyId != null) {
      map['company_id'] = Variable<String>(companyId);
    }
    if (!nullToAbsent || clientName != null) {
      map['client_name'] = Variable<String>(clientName);
    }
    if (!nullToAbsent || clientPhone != null) {
      map['client_phone'] = Variable<String>(clientPhone);
    }
    map['reminder_title'] = Variable<String>(reminderTitle);
    if (!nullToAbsent || reminderDetails != null) {
      map['reminder_details'] = Variable<String>(reminderDetails);
    }
    map['reminder_date'] = Variable<String>(reminderDate);
    map['reminder_time'] = Variable<String>(reminderTime);
    map['notification_status'] = Variable<String>(notificationStatus);
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  RemindersCompanion toCompanion(bool nullToAbsent) {
    return RemindersCompanion(
      reminderId: Value(reminderId),
      agentId: Value(agentId),
      companyId: companyId == null && nullToAbsent
          ? const Value.absent()
          : Value(companyId),
      clientName: clientName == null && nullToAbsent
          ? const Value.absent()
          : Value(clientName),
      clientPhone: clientPhone == null && nullToAbsent
          ? const Value.absent()
          : Value(clientPhone),
      reminderTitle: Value(reminderTitle),
      reminderDetails: reminderDetails == null && nullToAbsent
          ? const Value.absent()
          : Value(reminderDetails),
      reminderDate: Value(reminderDate),
      reminderTime: Value(reminderTime),
      notificationStatus: Value(notificationStatus),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Reminder.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Reminder(
      reminderId: serializer.fromJson<int>(json['reminderId']),
      agentId: serializer.fromJson<String>(json['agentId']),
      companyId: serializer.fromJson<String?>(json['companyId']),
      clientName: serializer.fromJson<String?>(json['clientName']),
      clientPhone: serializer.fromJson<String?>(json['clientPhone']),
      reminderTitle: serializer.fromJson<String>(json['reminderTitle']),
      reminderDetails: serializer.fromJson<String?>(json['reminderDetails']),
      reminderDate: serializer.fromJson<String>(json['reminderDate']),
      reminderTime: serializer.fromJson<String>(json['reminderTime']),
      notificationStatus:
          serializer.fromJson<String>(json['notificationStatus']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'reminderId': serializer.toJson<int>(reminderId),
      'agentId': serializer.toJson<String>(agentId),
      'companyId': serializer.toJson<String?>(companyId),
      'clientName': serializer.toJson<String?>(clientName),
      'clientPhone': serializer.toJson<String?>(clientPhone),
      'reminderTitle': serializer.toJson<String>(reminderTitle),
      'reminderDetails': serializer.toJson<String?>(reminderDetails),
      'reminderDate': serializer.toJson<String>(reminderDate),
      'reminderTime': serializer.toJson<String>(reminderTime),
      'notificationStatus': serializer.toJson<String>(notificationStatus),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  Reminder copyWith(
          {int? reminderId,
          String? agentId,
          Value<String?> companyId = const Value.absent(),
          Value<String?> clientName = const Value.absent(),
          Value<String?> clientPhone = const Value.absent(),
          String? reminderTitle,
          Value<String?> reminderDetails = const Value.absent(),
          String? reminderDate,
          String? reminderTime,
          String? notificationStatus,
          bool? isActive,
          String? createdAt,
          String? updatedAt}) =>
      Reminder(
        reminderId: reminderId ?? this.reminderId,
        agentId: agentId ?? this.agentId,
        companyId: companyId.present ? companyId.value : this.companyId,
        clientName: clientName.present ? clientName.value : this.clientName,
        clientPhone: clientPhone.present ? clientPhone.value : this.clientPhone,
        reminderTitle: reminderTitle ?? this.reminderTitle,
        reminderDetails: reminderDetails.present
            ? reminderDetails.value
            : this.reminderDetails,
        reminderDate: reminderDate ?? this.reminderDate,
        reminderTime: reminderTime ?? this.reminderTime,
        notificationStatus: notificationStatus ?? this.notificationStatus,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Reminder copyWithCompanion(RemindersCompanion data) {
    return Reminder(
      reminderId:
          data.reminderId.present ? data.reminderId.value : this.reminderId,
      agentId: data.agentId.present ? data.agentId.value : this.agentId,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      clientName:
          data.clientName.present ? data.clientName.value : this.clientName,
      clientPhone:
          data.clientPhone.present ? data.clientPhone.value : this.clientPhone,
      reminderTitle: data.reminderTitle.present
          ? data.reminderTitle.value
          : this.reminderTitle,
      reminderDetails: data.reminderDetails.present
          ? data.reminderDetails.value
          : this.reminderDetails,
      reminderDate: data.reminderDate.present
          ? data.reminderDate.value
          : this.reminderDate,
      reminderTime: data.reminderTime.present
          ? data.reminderTime.value
          : this.reminderTime,
      notificationStatus: data.notificationStatus.present
          ? data.notificationStatus.value
          : this.notificationStatus,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Reminder(')
          ..write('reminderId: $reminderId, ')
          ..write('agentId: $agentId, ')
          ..write('companyId: $companyId, ')
          ..write('clientName: $clientName, ')
          ..write('clientPhone: $clientPhone, ')
          ..write('reminderTitle: $reminderTitle, ')
          ..write('reminderDetails: $reminderDetails, ')
          ..write('reminderDate: $reminderDate, ')
          ..write('reminderTime: $reminderTime, ')
          ..write('notificationStatus: $notificationStatus, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      reminderId,
      agentId,
      companyId,
      clientName,
      clientPhone,
      reminderTitle,
      reminderDetails,
      reminderDate,
      reminderTime,
      notificationStatus,
      isActive,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Reminder &&
          other.reminderId == this.reminderId &&
          other.agentId == this.agentId &&
          other.companyId == this.companyId &&
          other.clientName == this.clientName &&
          other.clientPhone == this.clientPhone &&
          other.reminderTitle == this.reminderTitle &&
          other.reminderDetails == this.reminderDetails &&
          other.reminderDate == this.reminderDate &&
          other.reminderTime == this.reminderTime &&
          other.notificationStatus == this.notificationStatus &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class RemindersCompanion extends UpdateCompanion<Reminder> {
  final Value<int> reminderId;
  final Value<String> agentId;
  final Value<String?> companyId;
  final Value<String?> clientName;
  final Value<String?> clientPhone;
  final Value<String> reminderTitle;
  final Value<String?> reminderDetails;
  final Value<String> reminderDate;
  final Value<String> reminderTime;
  final Value<String> notificationStatus;
  final Value<bool> isActive;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  const RemindersCompanion({
    this.reminderId = const Value.absent(),
    this.agentId = const Value.absent(),
    this.companyId = const Value.absent(),
    this.clientName = const Value.absent(),
    this.clientPhone = const Value.absent(),
    this.reminderTitle = const Value.absent(),
    this.reminderDetails = const Value.absent(),
    this.reminderDate = const Value.absent(),
    this.reminderTime = const Value.absent(),
    this.notificationStatus = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  RemindersCompanion.insert({
    this.reminderId = const Value.absent(),
    required String agentId,
    this.companyId = const Value.absent(),
    this.clientName = const Value.absent(),
    this.clientPhone = const Value.absent(),
    required String reminderTitle,
    this.reminderDetails = const Value.absent(),
    required String reminderDate,
    required String reminderTime,
    required String notificationStatus,
    this.isActive = const Value.absent(),
    required String createdAt,
    required String updatedAt,
  })  : agentId = Value(agentId),
        reminderTitle = Value(reminderTitle),
        reminderDate = Value(reminderDate),
        reminderTime = Value(reminderTime),
        notificationStatus = Value(notificationStatus),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<Reminder> custom({
    Expression<int>? reminderId,
    Expression<String>? agentId,
    Expression<String>? companyId,
    Expression<String>? clientName,
    Expression<String>? clientPhone,
    Expression<String>? reminderTitle,
    Expression<String>? reminderDetails,
    Expression<String>? reminderDate,
    Expression<String>? reminderTime,
    Expression<String>? notificationStatus,
    Expression<bool>? isActive,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (reminderId != null) 'reminder_id': reminderId,
      if (agentId != null) 'agent_id': agentId,
      if (companyId != null) 'company_id': companyId,
      if (clientName != null) 'client_name': clientName,
      if (clientPhone != null) 'client_phone': clientPhone,
      if (reminderTitle != null) 'reminder_title': reminderTitle,
      if (reminderDetails != null) 'reminder_details': reminderDetails,
      if (reminderDate != null) 'reminder_date': reminderDate,
      if (reminderTime != null) 'reminder_time': reminderTime,
      if (notificationStatus != null) 'notification_status': notificationStatus,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  RemindersCompanion copyWith(
      {Value<int>? reminderId,
      Value<String>? agentId,
      Value<String?>? companyId,
      Value<String?>? clientName,
      Value<String?>? clientPhone,
      Value<String>? reminderTitle,
      Value<String?>? reminderDetails,
      Value<String>? reminderDate,
      Value<String>? reminderTime,
      Value<String>? notificationStatus,
      Value<bool>? isActive,
      Value<String>? createdAt,
      Value<String>? updatedAt}) {
    return RemindersCompanion(
      reminderId: reminderId ?? this.reminderId,
      agentId: agentId ?? this.agentId,
      companyId: companyId ?? this.companyId,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      reminderTitle: reminderTitle ?? this.reminderTitle,
      reminderDetails: reminderDetails ?? this.reminderDetails,
      reminderDate: reminderDate ?? this.reminderDate,
      reminderTime: reminderTime ?? this.reminderTime,
      notificationStatus: notificationStatus ?? this.notificationStatus,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (reminderId.present) {
      map['reminder_id'] = Variable<int>(reminderId.value);
    }
    if (agentId.present) {
      map['agent_id'] = Variable<String>(agentId.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (clientName.present) {
      map['client_name'] = Variable<String>(clientName.value);
    }
    if (clientPhone.present) {
      map['client_phone'] = Variable<String>(clientPhone.value);
    }
    if (reminderTitle.present) {
      map['reminder_title'] = Variable<String>(reminderTitle.value);
    }
    if (reminderDetails.present) {
      map['reminder_details'] = Variable<String>(reminderDetails.value);
    }
    if (reminderDate.present) {
      map['reminder_date'] = Variable<String>(reminderDate.value);
    }
    if (reminderTime.present) {
      map['reminder_time'] = Variable<String>(reminderTime.value);
    }
    if (notificationStatus.present) {
      map['notification_status'] = Variable<String>(notificationStatus.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RemindersCompanion(')
          ..write('reminderId: $reminderId, ')
          ..write('agentId: $agentId, ')
          ..write('companyId: $companyId, ')
          ..write('clientName: $clientName, ')
          ..write('clientPhone: $clientPhone, ')
          ..write('reminderTitle: $reminderTitle, ')
          ..write('reminderDetails: $reminderDetails, ')
          ..write('reminderDate: $reminderDate, ')
          ..write('reminderTime: $reminderTime, ')
          ..write('notificationStatus: $notificationStatus, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $ReportsTable extends Reports with TableInfo<$ReportsTable, Report> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReportsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _companyIdMeta =
      const VerificationMeta('companyId');
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
      'company_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _passwordMeta =
      const VerificationMeta('password');
  @override
  late final GeneratedColumn<String> password = GeneratedColumn<String>(
      'password', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _filePathMeta =
      const VerificationMeta('filePath');
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
      'file_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, companyId, name, password, filePath, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reports';
  @override
  VerificationContext validateIntegrity(Insertable<Report> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(_companyIdMeta,
          companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('password')) {
      context.handle(_passwordMeta,
          password.isAcceptableOrUnknown(data['password']!, _passwordMeta));
    }
    if (data.containsKey('file_path')) {
      context.handle(_filePathMeta,
          filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Report map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Report(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      companyId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}company_id']),
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      password: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}password']),
      filePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_path']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $ReportsTable createAlias(String alias) {
    return $ReportsTable(attachedDatabase, alias);
  }
}

class Report extends DataClass implements Insertable<Report> {
  final String id;
  final String? companyId;
  final String name;
  final String? password;
  final String? filePath;
  final String updatedAt;
  const Report(
      {required this.id,
      this.companyId,
      required this.name,
      this.password,
      this.filePath,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || companyId != null) {
      map['company_id'] = Variable<String>(companyId);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || password != null) {
      map['password'] = Variable<String>(password);
    }
    if (!nullToAbsent || filePath != null) {
      map['file_path'] = Variable<String>(filePath);
    }
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  ReportsCompanion toCompanion(bool nullToAbsent) {
    return ReportsCompanion(
      id: Value(id),
      companyId: companyId == null && nullToAbsent
          ? const Value.absent()
          : Value(companyId),
      name: Value(name),
      password: password == null && nullToAbsent
          ? const Value.absent()
          : Value(password),
      filePath: filePath == null && nullToAbsent
          ? const Value.absent()
          : Value(filePath),
      updatedAt: Value(updatedAt),
    );
  }

  factory Report.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Report(
      id: serializer.fromJson<String>(json['id']),
      companyId: serializer.fromJson<String?>(json['companyId']),
      name: serializer.fromJson<String>(json['name']),
      password: serializer.fromJson<String?>(json['password']),
      filePath: serializer.fromJson<String?>(json['filePath']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'companyId': serializer.toJson<String?>(companyId),
      'name': serializer.toJson<String>(name),
      'password': serializer.toJson<String?>(password),
      'filePath': serializer.toJson<String?>(filePath),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  Report copyWith(
          {String? id,
          Value<String?> companyId = const Value.absent(),
          String? name,
          Value<String?> password = const Value.absent(),
          Value<String?> filePath = const Value.absent(),
          String? updatedAt}) =>
      Report(
        id: id ?? this.id,
        companyId: companyId.present ? companyId.value : this.companyId,
        name: name ?? this.name,
        password: password.present ? password.value : this.password,
        filePath: filePath.present ? filePath.value : this.filePath,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Report copyWithCompanion(ReportsCompanion data) {
    return Report(
      id: data.id.present ? data.id.value : this.id,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      name: data.name.present ? data.name.value : this.name,
      password: data.password.present ? data.password.value : this.password,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Report(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('name: $name, ')
          ..write('password: $password, ')
          ..write('filePath: $filePath, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, companyId, name, password, filePath, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Report &&
          other.id == this.id &&
          other.companyId == this.companyId &&
          other.name == this.name &&
          other.password == this.password &&
          other.filePath == this.filePath &&
          other.updatedAt == this.updatedAt);
}

class ReportsCompanion extends UpdateCompanion<Report> {
  final Value<String> id;
  final Value<String?> companyId;
  final Value<String> name;
  final Value<String?> password;
  final Value<String?> filePath;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const ReportsCompanion({
    this.id = const Value.absent(),
    this.companyId = const Value.absent(),
    this.name = const Value.absent(),
    this.password = const Value.absent(),
    this.filePath = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReportsCompanion.insert({
    required String id,
    this.companyId = const Value.absent(),
    required String name,
    this.password = const Value.absent(),
    this.filePath = const Value.absent(),
    required String updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        updatedAt = Value(updatedAt);
  static Insertable<Report> custom({
    Expression<String>? id,
    Expression<String>? companyId,
    Expression<String>? name,
    Expression<String>? password,
    Expression<String>? filePath,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (companyId != null) 'company_id': companyId,
      if (name != null) 'name': name,
      if (password != null) 'password': password,
      if (filePath != null) 'file_path': filePath,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReportsCompanion copyWith(
      {Value<String>? id,
      Value<String?>? companyId,
      Value<String>? name,
      Value<String?>? password,
      Value<String?>? filePath,
      Value<String>? updatedAt,
      Value<int>? rowid}) {
    return ReportsCompanion(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      password: password ?? this.password,
      filePath: filePath ?? this.filePath,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (password.present) {
      map['password'] = Variable<String>(password.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReportsCompanion(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('name: $name, ')
          ..write('password: $password, ')
          ..write('filePath: $filePath, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DeletionsTable extends Deletions
    with TableInfo<$DeletionsTable, Deletion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeletionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _moduleMeta = const VerificationMeta('module');
  @override
  late final GeneratedColumn<String> module = GeneratedColumn<String>(
      'module', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _entityIdMeta =
      const VerificationMeta('entityId');
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
      'entity_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _companyIdMeta =
      const VerificationMeta('companyId');
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
      'company_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, module, entityId, companyId, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'deletions';
  @override
  VerificationContext validateIntegrity(Insertable<Deletion> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('module')) {
      context.handle(_moduleMeta,
          module.isAcceptableOrUnknown(data['module']!, _moduleMeta));
    } else if (isInserting) {
      context.missing(_moduleMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(_entityIdMeta,
          entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta));
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(_companyIdMeta,
          companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Deletion map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Deletion(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      module: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}module'])!,
      entityId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_id'])!,
      companyId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}company_id']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $DeletionsTable createAlias(String alias) {
    return $DeletionsTable(attachedDatabase, alias);
  }
}

class Deletion extends DataClass implements Insertable<Deletion> {
  final int id;
  final String module;
  final String entityId;
  final String? companyId;
  final String updatedAt;
  const Deletion(
      {required this.id,
      required this.module,
      required this.entityId,
      this.companyId,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['module'] = Variable<String>(module);
    map['entity_id'] = Variable<String>(entityId);
    if (!nullToAbsent || companyId != null) {
      map['company_id'] = Variable<String>(companyId);
    }
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  DeletionsCompanion toCompanion(bool nullToAbsent) {
    return DeletionsCompanion(
      id: Value(id),
      module: Value(module),
      entityId: Value(entityId),
      companyId: companyId == null && nullToAbsent
          ? const Value.absent()
          : Value(companyId),
      updatedAt: Value(updatedAt),
    );
  }

  factory Deletion.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Deletion(
      id: serializer.fromJson<int>(json['id']),
      module: serializer.fromJson<String>(json['module']),
      entityId: serializer.fromJson<String>(json['entityId']),
      companyId: serializer.fromJson<String?>(json['companyId']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'module': serializer.toJson<String>(module),
      'entityId': serializer.toJson<String>(entityId),
      'companyId': serializer.toJson<String?>(companyId),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  Deletion copyWith(
          {int? id,
          String? module,
          String? entityId,
          Value<String?> companyId = const Value.absent(),
          String? updatedAt}) =>
      Deletion(
        id: id ?? this.id,
        module: module ?? this.module,
        entityId: entityId ?? this.entityId,
        companyId: companyId.present ? companyId.value : this.companyId,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Deletion copyWithCompanion(DeletionsCompanion data) {
    return Deletion(
      id: data.id.present ? data.id.value : this.id,
      module: data.module.present ? data.module.value : this.module,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Deletion(')
          ..write('id: $id, ')
          ..write('module: $module, ')
          ..write('entityId: $entityId, ')
          ..write('companyId: $companyId, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, module, entityId, companyId, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Deletion &&
          other.id == this.id &&
          other.module == this.module &&
          other.entityId == this.entityId &&
          other.companyId == this.companyId &&
          other.updatedAt == this.updatedAt);
}

class DeletionsCompanion extends UpdateCompanion<Deletion> {
  final Value<int> id;
  final Value<String> module;
  final Value<String> entityId;
  final Value<String?> companyId;
  final Value<String> updatedAt;
  const DeletionsCompanion({
    this.id = const Value.absent(),
    this.module = const Value.absent(),
    this.entityId = const Value.absent(),
    this.companyId = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  DeletionsCompanion.insert({
    this.id = const Value.absent(),
    required String module,
    required String entityId,
    this.companyId = const Value.absent(),
    required String updatedAt,
  })  : module = Value(module),
        entityId = Value(entityId),
        updatedAt = Value(updatedAt);
  static Insertable<Deletion> custom({
    Expression<int>? id,
    Expression<String>? module,
    Expression<String>? entityId,
    Expression<String>? companyId,
    Expression<String>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (module != null) 'module': module,
      if (entityId != null) 'entity_id': entityId,
      if (companyId != null) 'company_id': companyId,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  DeletionsCompanion copyWith(
      {Value<int>? id,
      Value<String>? module,
      Value<String>? entityId,
      Value<String?>? companyId,
      Value<String>? updatedAt}) {
    return DeletionsCompanion(
      id: id ?? this.id,
      module: module ?? this.module,
      entityId: entityId ?? this.entityId,
      companyId: companyId ?? this.companyId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (module.present) {
      map['module'] = Variable<String>(module.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeletionsCompanion(')
          ..write('id: $id, ')
          ..write('module: $module, ')
          ..write('entityId: $entityId, ')
          ..write('companyId: $companyId, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $SyncLogsTable extends SyncLogs with TableInfo<$SyncLogsTable, SyncLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _directionMeta =
      const VerificationMeta('direction');
  @override
  late final GeneratedColumn<String> direction = GeneratedColumn<String>(
      'direction', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _moduleMeta = const VerificationMeta('module');
  @override
  late final GeneratedColumn<String> module = GeneratedColumn<String>(
      'module', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _exportIdMeta =
      const VerificationMeta('exportId');
  @override
  late final GeneratedColumn<String> exportId = GeneratedColumn<String>(
      'export_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _fileNameMeta =
      const VerificationMeta('fileName');
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
      'file_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
      'error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _companyIdMeta =
      const VerificationMeta('companyId');
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
      'company_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _startedAtMeta =
      const VerificationMeta('startedAt');
  @override
  late final GeneratedColumn<String> startedAt = GeneratedColumn<String>(
      'started_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _finishedAtMeta =
      const VerificationMeta('finishedAt');
  @override
  late final GeneratedColumn<String> finishedAt = GeneratedColumn<String>(
      'finished_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        direction,
        module,
        exportId,
        fileName,
        status,
        error,
        companyId,
        startedAt,
        finishedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_logs';
  @override
  VerificationContext validateIntegrity(Insertable<SyncLog> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('direction')) {
      context.handle(_directionMeta,
          direction.isAcceptableOrUnknown(data['direction']!, _directionMeta));
    } else if (isInserting) {
      context.missing(_directionMeta);
    }
    if (data.containsKey('module')) {
      context.handle(_moduleMeta,
          module.isAcceptableOrUnknown(data['module']!, _moduleMeta));
    }
    if (data.containsKey('export_id')) {
      context.handle(_exportIdMeta,
          exportId.isAcceptableOrUnknown(data['export_id']!, _exportIdMeta));
    }
    if (data.containsKey('file_name')) {
      context.handle(_fileNameMeta,
          fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('error')) {
      context.handle(
          _errorMeta, error.isAcceptableOrUnknown(data['error']!, _errorMeta));
    }
    if (data.containsKey('company_id')) {
      context.handle(_companyIdMeta,
          companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta));
    }
    if (data.containsKey('started_at')) {
      context.handle(_startedAtMeta,
          startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta));
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('finished_at')) {
      context.handle(
          _finishedAtMeta,
          finishedAt.isAcceptableOrUnknown(
              data['finished_at']!, _finishedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncLog(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      direction: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}direction'])!,
      module: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}module']),
      exportId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}export_id']),
      fileName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_name']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      error: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}error']),
      companyId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}company_id']),
      startedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}started_at'])!,
      finishedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}finished_at']),
    );
  }

  @override
  $SyncLogsTable createAlias(String alias) {
    return $SyncLogsTable(attachedDatabase, alias);
  }
}

class SyncLog extends DataClass implements Insertable<SyncLog> {
  final int id;
  final String direction;
  final String? module;
  final String? exportId;
  final String? fileName;
  final String status;
  final String? error;
  final String? companyId;
  final String startedAt;
  final String? finishedAt;
  const SyncLog(
      {required this.id,
      required this.direction,
      this.module,
      this.exportId,
      this.fileName,
      required this.status,
      this.error,
      this.companyId,
      required this.startedAt,
      this.finishedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['direction'] = Variable<String>(direction);
    if (!nullToAbsent || module != null) {
      map['module'] = Variable<String>(module);
    }
    if (!nullToAbsent || exportId != null) {
      map['export_id'] = Variable<String>(exportId);
    }
    if (!nullToAbsent || fileName != null) {
      map['file_name'] = Variable<String>(fileName);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    if (!nullToAbsent || companyId != null) {
      map['company_id'] = Variable<String>(companyId);
    }
    map['started_at'] = Variable<String>(startedAt);
    if (!nullToAbsent || finishedAt != null) {
      map['finished_at'] = Variable<String>(finishedAt);
    }
    return map;
  }

  SyncLogsCompanion toCompanion(bool nullToAbsent) {
    return SyncLogsCompanion(
      id: Value(id),
      direction: Value(direction),
      module:
          module == null && nullToAbsent ? const Value.absent() : Value(module),
      exportId: exportId == null && nullToAbsent
          ? const Value.absent()
          : Value(exportId),
      fileName: fileName == null && nullToAbsent
          ? const Value.absent()
          : Value(fileName),
      status: Value(status),
      error:
          error == null && nullToAbsent ? const Value.absent() : Value(error),
      companyId: companyId == null && nullToAbsent
          ? const Value.absent()
          : Value(companyId),
      startedAt: Value(startedAt),
      finishedAt: finishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(finishedAt),
    );
  }

  factory SyncLog.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncLog(
      id: serializer.fromJson<int>(json['id']),
      direction: serializer.fromJson<String>(json['direction']),
      module: serializer.fromJson<String?>(json['module']),
      exportId: serializer.fromJson<String?>(json['exportId']),
      fileName: serializer.fromJson<String?>(json['fileName']),
      status: serializer.fromJson<String>(json['status']),
      error: serializer.fromJson<String?>(json['error']),
      companyId: serializer.fromJson<String?>(json['companyId']),
      startedAt: serializer.fromJson<String>(json['startedAt']),
      finishedAt: serializer.fromJson<String?>(json['finishedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'direction': serializer.toJson<String>(direction),
      'module': serializer.toJson<String?>(module),
      'exportId': serializer.toJson<String?>(exportId),
      'fileName': serializer.toJson<String?>(fileName),
      'status': serializer.toJson<String>(status),
      'error': serializer.toJson<String?>(error),
      'companyId': serializer.toJson<String?>(companyId),
      'startedAt': serializer.toJson<String>(startedAt),
      'finishedAt': serializer.toJson<String?>(finishedAt),
    };
  }

  SyncLog copyWith(
          {int? id,
          String? direction,
          Value<String?> module = const Value.absent(),
          Value<String?> exportId = const Value.absent(),
          Value<String?> fileName = const Value.absent(),
          String? status,
          Value<String?> error = const Value.absent(),
          Value<String?> companyId = const Value.absent(),
          String? startedAt,
          Value<String?> finishedAt = const Value.absent()}) =>
      SyncLog(
        id: id ?? this.id,
        direction: direction ?? this.direction,
        module: module.present ? module.value : this.module,
        exportId: exportId.present ? exportId.value : this.exportId,
        fileName: fileName.present ? fileName.value : this.fileName,
        status: status ?? this.status,
        error: error.present ? error.value : this.error,
        companyId: companyId.present ? companyId.value : this.companyId,
        startedAt: startedAt ?? this.startedAt,
        finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
      );
  SyncLog copyWithCompanion(SyncLogsCompanion data) {
    return SyncLog(
      id: data.id.present ? data.id.value : this.id,
      direction: data.direction.present ? data.direction.value : this.direction,
      module: data.module.present ? data.module.value : this.module,
      exportId: data.exportId.present ? data.exportId.value : this.exportId,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      status: data.status.present ? data.status.value : this.status,
      error: data.error.present ? data.error.value : this.error,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      finishedAt:
          data.finishedAt.present ? data.finishedAt.value : this.finishedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncLog(')
          ..write('id: $id, ')
          ..write('direction: $direction, ')
          ..write('module: $module, ')
          ..write('exportId: $exportId, ')
          ..write('fileName: $fileName, ')
          ..write('status: $status, ')
          ..write('error: $error, ')
          ..write('companyId: $companyId, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, direction, module, exportId, fileName,
      status, error, companyId, startedAt, finishedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncLog &&
          other.id == this.id &&
          other.direction == this.direction &&
          other.module == this.module &&
          other.exportId == this.exportId &&
          other.fileName == this.fileName &&
          other.status == this.status &&
          other.error == this.error &&
          other.companyId == this.companyId &&
          other.startedAt == this.startedAt &&
          other.finishedAt == this.finishedAt);
}

class SyncLogsCompanion extends UpdateCompanion<SyncLog> {
  final Value<int> id;
  final Value<String> direction;
  final Value<String?> module;
  final Value<String?> exportId;
  final Value<String?> fileName;
  final Value<String> status;
  final Value<String?> error;
  final Value<String?> companyId;
  final Value<String> startedAt;
  final Value<String?> finishedAt;
  const SyncLogsCompanion({
    this.id = const Value.absent(),
    this.direction = const Value.absent(),
    this.module = const Value.absent(),
    this.exportId = const Value.absent(),
    this.fileName = const Value.absent(),
    this.status = const Value.absent(),
    this.error = const Value.absent(),
    this.companyId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
  });
  SyncLogsCompanion.insert({
    this.id = const Value.absent(),
    required String direction,
    this.module = const Value.absent(),
    this.exportId = const Value.absent(),
    this.fileName = const Value.absent(),
    required String status,
    this.error = const Value.absent(),
    this.companyId = const Value.absent(),
    required String startedAt,
    this.finishedAt = const Value.absent(),
  })  : direction = Value(direction),
        status = Value(status),
        startedAt = Value(startedAt);
  static Insertable<SyncLog> custom({
    Expression<int>? id,
    Expression<String>? direction,
    Expression<String>? module,
    Expression<String>? exportId,
    Expression<String>? fileName,
    Expression<String>? status,
    Expression<String>? error,
    Expression<String>? companyId,
    Expression<String>? startedAt,
    Expression<String>? finishedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (direction != null) 'direction': direction,
      if (module != null) 'module': module,
      if (exportId != null) 'export_id': exportId,
      if (fileName != null) 'file_name': fileName,
      if (status != null) 'status': status,
      if (error != null) 'error': error,
      if (companyId != null) 'company_id': companyId,
      if (startedAt != null) 'started_at': startedAt,
      if (finishedAt != null) 'finished_at': finishedAt,
    });
  }

  SyncLogsCompanion copyWith(
      {Value<int>? id,
      Value<String>? direction,
      Value<String?>? module,
      Value<String?>? exportId,
      Value<String?>? fileName,
      Value<String>? status,
      Value<String?>? error,
      Value<String?>? companyId,
      Value<String>? startedAt,
      Value<String?>? finishedAt}) {
    return SyncLogsCompanion(
      id: id ?? this.id,
      direction: direction ?? this.direction,
      module: module ?? this.module,
      exportId: exportId ?? this.exportId,
      fileName: fileName ?? this.fileName,
      status: status ?? this.status,
      error: error ?? this.error,
      companyId: companyId ?? this.companyId,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(direction.value);
    }
    if (module.present) {
      map['module'] = Variable<String>(module.value);
    }
    if (exportId.present) {
      map['export_id'] = Variable<String>(exportId.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<String>(startedAt.value);
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<String>(finishedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncLogsCompanion(')
          ..write('id: $id, ')
          ..write('direction: $direction, ')
          ..write('module: $module, ')
          ..write('exportId: $exportId, ')
          ..write('fileName: $fileName, ')
          ..write('status: $status, ')
          ..write('error: $error, ')
          ..write('companyId: $companyId, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt')
          ..write(')'))
        .toString();
  }
}

class $ClientsTable extends Clients with TableInfo<$ClientsTable, Client> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClientsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _companyIdMeta =
      const VerificationMeta('companyId');
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
      'company_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdByMeta =
      const VerificationMeta('createdBy');
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
      'created_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _clientNameMeta =
      const VerificationMeta('clientName');
  @override
  late final GeneratedColumn<String> clientName = GeneratedColumn<String>(
      'client_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _clientContactMeta =
      const VerificationMeta('clientContact');
  @override
  late final GeneratedColumn<String> clientContact = GeneratedColumn<String>(
      'client_contact', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _addressMeta =
      const VerificationMeta('address');
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
      'address', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cityMeta = const VerificationMeta('city');
  @override
  late final GeneratedColumn<String> city = GeneratedColumn<String>(
      'city', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _organizationMeta =
      const VerificationMeta('organization');
  @override
  late final GeneratedColumn<String> organization = GeneratedColumn<String>(
      'organization', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _plotMeta = const VerificationMeta('plot');
  @override
  late final GeneratedColumn<String> plot = GeneratedColumn<String>(
      'plot', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<String> size = GeneratedColumn<String>(
      'size', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _locationMeta =
      const VerificationMeta('location');
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
      'location', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _budgetMeta = const VerificationMeta('budget');
  @override
  late final GeneratedColumn<int> budget = GeneratedColumn<int>(
      'budget', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _remarksMeta =
      const VerificationMeta('remarks');
  @override
  late final GeneratedColumn<String> remarks = GeneratedColumn<String>(
      'remarks', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
      'date', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        companyId,
        createdBy,
        clientName,
        clientContact,
        address,
        city,
        organization,
        plot,
        size,
        location,
        budget,
        remarks,
        date,
        source,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'clients';
  @override
  VerificationContext validateIntegrity(Insertable<Client> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(_companyIdMeta,
          companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta));
    }
    if (data.containsKey('created_by')) {
      context.handle(_createdByMeta,
          createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta));
    }
    if (data.containsKey('client_name')) {
      context.handle(
          _clientNameMeta,
          clientName.isAcceptableOrUnknown(
              data['client_name']!, _clientNameMeta));
    } else if (isInserting) {
      context.missing(_clientNameMeta);
    }
    if (data.containsKey('client_contact')) {
      context.handle(
          _clientContactMeta,
          clientContact.isAcceptableOrUnknown(
              data['client_contact']!, _clientContactMeta));
    }
    if (data.containsKey('address')) {
      context.handle(_addressMeta,
          address.isAcceptableOrUnknown(data['address']!, _addressMeta));
    }
    if (data.containsKey('city')) {
      context.handle(
          _cityMeta, city.isAcceptableOrUnknown(data['city']!, _cityMeta));
    }
    if (data.containsKey('organization')) {
      context.handle(
          _organizationMeta,
          organization.isAcceptableOrUnknown(
              data['organization']!, _organizationMeta));
    }
    if (data.containsKey('plot')) {
      context.handle(
          _plotMeta, plot.isAcceptableOrUnknown(data['plot']!, _plotMeta));
    }
    if (data.containsKey('size')) {
      context.handle(
          _sizeMeta, size.isAcceptableOrUnknown(data['size']!, _sizeMeta));
    }
    if (data.containsKey('location')) {
      context.handle(_locationMeta,
          location.isAcceptableOrUnknown(data['location']!, _locationMeta));
    }
    if (data.containsKey('budget')) {
      context.handle(_budgetMeta,
          budget.isAcceptableOrUnknown(data['budget']!, _budgetMeta));
    }
    if (data.containsKey('remarks')) {
      context.handle(_remarksMeta,
          remarks.isAcceptableOrUnknown(data['remarks']!, _remarksMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
          _dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Client map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Client(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      companyId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}company_id']),
      createdBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}created_by']),
      clientName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}client_name'])!,
      clientContact: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}client_contact']),
      address: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}address']),
      city: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}city']),
      organization: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}organization']),
      plot: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}plot']),
      size: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}size']),
      location: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}location']),
      budget: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}budget']),
      remarks: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}remarks']),
      date: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}date']),
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $ClientsTable createAlias(String alias) {
    return $ClientsTable(attachedDatabase, alias);
  }
}

class Client extends DataClass implements Insertable<Client> {
  final String id;
  final String? companyId;
  final String? createdBy;
  final String clientName;
  final String? clientContact;
  final String? address;
  final String? city;
  final String? organization;
  final String? plot;
  final String? size;
  final String? location;
  final int? budget;
  final String? remarks;
  final String? date;
  final String? source;
  final String updatedAt;
  const Client(
      {required this.id,
      this.companyId,
      this.createdBy,
      required this.clientName,
      this.clientContact,
      this.address,
      this.city,
      this.organization,
      this.plot,
      this.size,
      this.location,
      this.budget,
      this.remarks,
      this.date,
      this.source,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || companyId != null) {
      map['company_id'] = Variable<String>(companyId);
    }
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<String>(createdBy);
    }
    map['client_name'] = Variable<String>(clientName);
    if (!nullToAbsent || clientContact != null) {
      map['client_contact'] = Variable<String>(clientContact);
    }
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    if (!nullToAbsent || city != null) {
      map['city'] = Variable<String>(city);
    }
    if (!nullToAbsent || organization != null) {
      map['organization'] = Variable<String>(organization);
    }
    if (!nullToAbsent || plot != null) {
      map['plot'] = Variable<String>(plot);
    }
    if (!nullToAbsent || size != null) {
      map['size'] = Variable<String>(size);
    }
    if (!nullToAbsent || location != null) {
      map['location'] = Variable<String>(location);
    }
    if (!nullToAbsent || budget != null) {
      map['budget'] = Variable<int>(budget);
    }
    if (!nullToAbsent || remarks != null) {
      map['remarks'] = Variable<String>(remarks);
    }
    if (!nullToAbsent || date != null) {
      map['date'] = Variable<String>(date);
    }
    if (!nullToAbsent || source != null) {
      map['source'] = Variable<String>(source);
    }
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  ClientsCompanion toCompanion(bool nullToAbsent) {
    return ClientsCompanion(
      id: Value(id),
      companyId: companyId == null && nullToAbsent
          ? const Value.absent()
          : Value(companyId),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      clientName: Value(clientName),
      clientContact: clientContact == null && nullToAbsent
          ? const Value.absent()
          : Value(clientContact),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      city: city == null && nullToAbsent ? const Value.absent() : Value(city),
      organization: organization == null && nullToAbsent
          ? const Value.absent()
          : Value(organization),
      plot: plot == null && nullToAbsent ? const Value.absent() : Value(plot),
      size: size == null && nullToAbsent ? const Value.absent() : Value(size),
      location: location == null && nullToAbsent
          ? const Value.absent()
          : Value(location),
      budget:
          budget == null && nullToAbsent ? const Value.absent() : Value(budget),
      remarks: remarks == null && nullToAbsent
          ? const Value.absent()
          : Value(remarks),
      date: date == null && nullToAbsent ? const Value.absent() : Value(date),
      source:
          source == null && nullToAbsent ? const Value.absent() : Value(source),
      updatedAt: Value(updatedAt),
    );
  }

  factory Client.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Client(
      id: serializer.fromJson<String>(json['id']),
      companyId: serializer.fromJson<String?>(json['companyId']),
      createdBy: serializer.fromJson<String?>(json['createdBy']),
      clientName: serializer.fromJson<String>(json['clientName']),
      clientContact: serializer.fromJson<String?>(json['clientContact']),
      address: serializer.fromJson<String?>(json['address']),
      city: serializer.fromJson<String?>(json['city']),
      organization: serializer.fromJson<String?>(json['organization']),
      plot: serializer.fromJson<String?>(json['plot']),
      size: serializer.fromJson<String?>(json['size']),
      location: serializer.fromJson<String?>(json['location']),
      budget: serializer.fromJson<int?>(json['budget']),
      remarks: serializer.fromJson<String?>(json['remarks']),
      date: serializer.fromJson<String?>(json['date']),
      source: serializer.fromJson<String?>(json['source']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'companyId': serializer.toJson<String?>(companyId),
      'createdBy': serializer.toJson<String?>(createdBy),
      'clientName': serializer.toJson<String>(clientName),
      'clientContact': serializer.toJson<String?>(clientContact),
      'address': serializer.toJson<String?>(address),
      'city': serializer.toJson<String?>(city),
      'organization': serializer.toJson<String?>(organization),
      'plot': serializer.toJson<String?>(plot),
      'size': serializer.toJson<String?>(size),
      'location': serializer.toJson<String?>(location),
      'budget': serializer.toJson<int?>(budget),
      'remarks': serializer.toJson<String?>(remarks),
      'date': serializer.toJson<String?>(date),
      'source': serializer.toJson<String?>(source),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  Client copyWith(
          {String? id,
          Value<String?> companyId = const Value.absent(),
          Value<String?> createdBy = const Value.absent(),
          String? clientName,
          Value<String?> clientContact = const Value.absent(),
          Value<String?> address = const Value.absent(),
          Value<String?> city = const Value.absent(),
          Value<String?> organization = const Value.absent(),
          Value<String?> plot = const Value.absent(),
          Value<String?> size = const Value.absent(),
          Value<String?> location = const Value.absent(),
          Value<int?> budget = const Value.absent(),
          Value<String?> remarks = const Value.absent(),
          Value<String?> date = const Value.absent(),
          Value<String?> source = const Value.absent(),
          String? updatedAt}) =>
      Client(
        id: id ?? this.id,
        companyId: companyId.present ? companyId.value : this.companyId,
        createdBy: createdBy.present ? createdBy.value : this.createdBy,
        clientName: clientName ?? this.clientName,
        clientContact:
            clientContact.present ? clientContact.value : this.clientContact,
        address: address.present ? address.value : this.address,
        city: city.present ? city.value : this.city,
        organization:
            organization.present ? organization.value : this.organization,
        plot: plot.present ? plot.value : this.plot,
        size: size.present ? size.value : this.size,
        location: location.present ? location.value : this.location,
        budget: budget.present ? budget.value : this.budget,
        remarks: remarks.present ? remarks.value : this.remarks,
        date: date.present ? date.value : this.date,
        source: source.present ? source.value : this.source,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Client copyWithCompanion(ClientsCompanion data) {
    return Client(
      id: data.id.present ? data.id.value : this.id,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      clientName:
          data.clientName.present ? data.clientName.value : this.clientName,
      clientContact: data.clientContact.present
          ? data.clientContact.value
          : this.clientContact,
      address: data.address.present ? data.address.value : this.address,
      city: data.city.present ? data.city.value : this.city,
      organization: data.organization.present
          ? data.organization.value
          : this.organization,
      plot: data.plot.present ? data.plot.value : this.plot,
      size: data.size.present ? data.size.value : this.size,
      location: data.location.present ? data.location.value : this.location,
      budget: data.budget.present ? data.budget.value : this.budget,
      remarks: data.remarks.present ? data.remarks.value : this.remarks,
      date: data.date.present ? data.date.value : this.date,
      source: data.source.present ? data.source.value : this.source,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Client(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('createdBy: $createdBy, ')
          ..write('clientName: $clientName, ')
          ..write('clientContact: $clientContact, ')
          ..write('address: $address, ')
          ..write('city: $city, ')
          ..write('organization: $organization, ')
          ..write('plot: $plot, ')
          ..write('size: $size, ')
          ..write('location: $location, ')
          ..write('budget: $budget, ')
          ..write('remarks: $remarks, ')
          ..write('date: $date, ')
          ..write('source: $source, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      companyId,
      createdBy,
      clientName,
      clientContact,
      address,
      city,
      organization,
      plot,
      size,
      location,
      budget,
      remarks,
      date,
      source,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Client &&
          other.id == this.id &&
          other.companyId == this.companyId &&
          other.createdBy == this.createdBy &&
          other.clientName == this.clientName &&
          other.clientContact == this.clientContact &&
          other.address == this.address &&
          other.city == this.city &&
          other.organization == this.organization &&
          other.plot == this.plot &&
          other.size == this.size &&
          other.location == this.location &&
          other.budget == this.budget &&
          other.remarks == this.remarks &&
          other.date == this.date &&
          other.source == this.source &&
          other.updatedAt == this.updatedAt);
}

class ClientsCompanion extends UpdateCompanion<Client> {
  final Value<String> id;
  final Value<String?> companyId;
  final Value<String?> createdBy;
  final Value<String> clientName;
  final Value<String?> clientContact;
  final Value<String?> address;
  final Value<String?> city;
  final Value<String?> organization;
  final Value<String?> plot;
  final Value<String?> size;
  final Value<String?> location;
  final Value<int?> budget;
  final Value<String?> remarks;
  final Value<String?> date;
  final Value<String?> source;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const ClientsCompanion({
    this.id = const Value.absent(),
    this.companyId = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.clientName = const Value.absent(),
    this.clientContact = const Value.absent(),
    this.address = const Value.absent(),
    this.city = const Value.absent(),
    this.organization = const Value.absent(),
    this.plot = const Value.absent(),
    this.size = const Value.absent(),
    this.location = const Value.absent(),
    this.budget = const Value.absent(),
    this.remarks = const Value.absent(),
    this.date = const Value.absent(),
    this.source = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ClientsCompanion.insert({
    required String id,
    this.companyId = const Value.absent(),
    this.createdBy = const Value.absent(),
    required String clientName,
    this.clientContact = const Value.absent(),
    this.address = const Value.absent(),
    this.city = const Value.absent(),
    this.organization = const Value.absent(),
    this.plot = const Value.absent(),
    this.size = const Value.absent(),
    this.location = const Value.absent(),
    this.budget = const Value.absent(),
    this.remarks = const Value.absent(),
    this.date = const Value.absent(),
    this.source = const Value.absent(),
    required String updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        clientName = Value(clientName),
        updatedAt = Value(updatedAt);
  static Insertable<Client> custom({
    Expression<String>? id,
    Expression<String>? companyId,
    Expression<String>? createdBy,
    Expression<String>? clientName,
    Expression<String>? clientContact,
    Expression<String>? address,
    Expression<String>? city,
    Expression<String>? organization,
    Expression<String>? plot,
    Expression<String>? size,
    Expression<String>? location,
    Expression<int>? budget,
    Expression<String>? remarks,
    Expression<String>? date,
    Expression<String>? source,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (companyId != null) 'company_id': companyId,
      if (createdBy != null) 'created_by': createdBy,
      if (clientName != null) 'client_name': clientName,
      if (clientContact != null) 'client_contact': clientContact,
      if (address != null) 'address': address,
      if (city != null) 'city': city,
      if (organization != null) 'organization': organization,
      if (plot != null) 'plot': plot,
      if (size != null) 'size': size,
      if (location != null) 'location': location,
      if (budget != null) 'budget': budget,
      if (remarks != null) 'remarks': remarks,
      if (date != null) 'date': date,
      if (source != null) 'source': source,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ClientsCompanion copyWith(
      {Value<String>? id,
      Value<String?>? companyId,
      Value<String?>? createdBy,
      Value<String>? clientName,
      Value<String?>? clientContact,
      Value<String?>? address,
      Value<String?>? city,
      Value<String?>? organization,
      Value<String?>? plot,
      Value<String?>? size,
      Value<String?>? location,
      Value<int?>? budget,
      Value<String?>? remarks,
      Value<String?>? date,
      Value<String?>? source,
      Value<String>? updatedAt,
      Value<int>? rowid}) {
    return ClientsCompanion(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      createdBy: createdBy ?? this.createdBy,
      clientName: clientName ?? this.clientName,
      clientContact: clientContact ?? this.clientContact,
      address: address ?? this.address,
      city: city ?? this.city,
      organization: organization ?? this.organization,
      plot: plot ?? this.plot,
      size: size ?? this.size,
      location: location ?? this.location,
      budget: budget ?? this.budget,
      remarks: remarks ?? this.remarks,
      date: date ?? this.date,
      source: source ?? this.source,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (clientName.present) {
      map['client_name'] = Variable<String>(clientName.value);
    }
    if (clientContact.present) {
      map['client_contact'] = Variable<String>(clientContact.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (city.present) {
      map['city'] = Variable<String>(city.value);
    }
    if (organization.present) {
      map['organization'] = Variable<String>(organization.value);
    }
    if (plot.present) {
      map['plot'] = Variable<String>(plot.value);
    }
    if (size.present) {
      map['size'] = Variable<String>(size.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (budget.present) {
      map['budget'] = Variable<int>(budget.value);
    }
    if (remarks.present) {
      map['remarks'] = Variable<String>(remarks.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClientsCompanion(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('createdBy: $createdBy, ')
          ..write('clientName: $clientName, ')
          ..write('clientContact: $clientContact, ')
          ..write('address: $address, ')
          ..write('city: $city, ')
          ..write('organization: $organization, ')
          ..write('plot: $plot, ')
          ..write('size: $size, ')
          ..write('location: $location, ')
          ..write('budget: $budget, ')
          ..write('remarks: $remarks, ')
          ..write('date: $date, ')
          ..write('source: $source, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CompaniesTable companies = $CompaniesTable(this);
  late final $UsersTable users = $UsersTable(this);
  late final $SocietiesTable societies = $SocietiesTable(this);
  late final $BlocksTable blocks = $BlocksTable(this);
  late final $PropertiesTable properties = $PropertiesTable(this);
  late final $PropertyCommentsTable propertyComments =
      $PropertyCommentsTable(this);
  late final $FilesTableTable filesTable = $FilesTableTable(this);
  late final $FileCommentsTable fileComments = $FileCommentsTable(this);
  late final $RentalItemsTable rentalItems = $RentalItemsTable(this);
  late final $RentalCommentsTable rentalComments = $RentalCommentsTable(this);
  late final $WorkingProgressTable workingProgress =
      $WorkingProgressTable(this);
  late final $WorkingCommentsTable workingComments =
      $WorkingCommentsTable(this);
  late final $RemindersTable reminders = $RemindersTable(this);
  late final $ReportsTable reports = $ReportsTable(this);
  late final $DeletionsTable deletions = $DeletionsTable(this);
  late final $SyncLogsTable syncLogs = $SyncLogsTable(this);
  late final $ClientsTable clients = $ClientsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        companies,
        users,
        societies,
        blocks,
        properties,
        propertyComments,
        filesTable,
        fileComments,
        rentalItems,
        rentalComments,
        workingProgress,
        workingComments,
        reminders,
        reports,
        deletions,
        syncLogs,
        clients
      ];
}

typedef $$CompaniesTableCreateCompanionBuilder = CompaniesCompanion Function({
  required String id,
  required String name,
  required String status,
  Value<String?> metadata,
  Value<int> maxUserLimit,
  Value<String> subscriptionTier,
  required String createdAt,
  required String updatedAt,
  Value<int> rowid,
});
typedef $$CompaniesTableUpdateCompanionBuilder = CompaniesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> status,
  Value<String?> metadata,
  Value<int> maxUserLimit,
  Value<String> subscriptionTier,
  Value<String> createdAt,
  Value<String> updatedAt,
  Value<int> rowid,
});

final class $$CompaniesTableReferences
    extends BaseReferences<_$AppDatabase, $CompaniesTable, Company> {
  $$CompaniesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$UsersTable, List<User>> _usersRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.users,
          aliasName: $_aliasNameGenerator(db.companies.id, db.users.companyId));

  $$UsersTableProcessedTableManager get usersRefs {
    final manager = $$UsersTableTableManager($_db, $_db.users)
        .filter((f) => f.companyId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_usersRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$CompaniesTableFilterComposer
    extends Composer<_$AppDatabase, $CompaniesTable> {
  $$CompaniesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get metadata => $composableBuilder(
      column: $table.metadata, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get maxUserLimit => $composableBuilder(
      column: $table.maxUserLimit, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get subscriptionTier => $composableBuilder(
      column: $table.subscriptionTier,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> usersRefs(
      Expression<bool> Function($$UsersTableFilterComposer f) f) {
    final $$UsersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.users,
        getReferencedColumn: (t) => t.companyId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$UsersTableFilterComposer(
              $db: $db,
              $table: $db.users,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$CompaniesTableOrderingComposer
    extends Composer<_$AppDatabase, $CompaniesTable> {
  $$CompaniesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get metadata => $composableBuilder(
      column: $table.metadata, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get maxUserLimit => $composableBuilder(
      column: $table.maxUserLimit,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get subscriptionTier => $composableBuilder(
      column: $table.subscriptionTier,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$CompaniesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CompaniesTable> {
  $$CompaniesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get metadata =>
      $composableBuilder(column: $table.metadata, builder: (column) => column);

  GeneratedColumn<int> get maxUserLimit => $composableBuilder(
      column: $table.maxUserLimit, builder: (column) => column);

  GeneratedColumn<String> get subscriptionTier => $composableBuilder(
      column: $table.subscriptionTier, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> usersRefs<T extends Object>(
      Expression<T> Function($$UsersTableAnnotationComposer a) f) {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.users,
        getReferencedColumn: (t) => t.companyId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$UsersTableAnnotationComposer(
              $db: $db,
              $table: $db.users,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$CompaniesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CompaniesTable,
    Company,
    $$CompaniesTableFilterComposer,
    $$CompaniesTableOrderingComposer,
    $$CompaniesTableAnnotationComposer,
    $$CompaniesTableCreateCompanionBuilder,
    $$CompaniesTableUpdateCompanionBuilder,
    (Company, $$CompaniesTableReferences),
    Company,
    PrefetchHooks Function({bool usersRefs})> {
  $$CompaniesTableTableManager(_$AppDatabase db, $CompaniesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CompaniesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CompaniesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CompaniesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> metadata = const Value.absent(),
            Value<int> maxUserLimit = const Value.absent(),
            Value<String> subscriptionTier = const Value.absent(),
            Value<String> createdAt = const Value.absent(),
            Value<String> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CompaniesCompanion(
            id: id,
            name: name,
            status: status,
            metadata: metadata,
            maxUserLimit: maxUserLimit,
            subscriptionTier: subscriptionTier,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String status,
            Value<String?> metadata = const Value.absent(),
            Value<int> maxUserLimit = const Value.absent(),
            Value<String> subscriptionTier = const Value.absent(),
            required String createdAt,
            required String updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              CompaniesCompanion.insert(
            id: id,
            name: name,
            status: status,
            metadata: metadata,
            maxUserLimit: maxUserLimit,
            subscriptionTier: subscriptionTier,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$CompaniesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({usersRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (usersRefs) db.users],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (usersRefs)
                    await $_getPrefetchedData<Company, $CompaniesTable, User>(
                        currentTable: table,
                        referencedTable:
                            $$CompaniesTableReferences._usersRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$CompaniesTableReferences(db, table, p0).usersRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.companyId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$CompaniesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CompaniesTable,
    Company,
    $$CompaniesTableFilterComposer,
    $$CompaniesTableOrderingComposer,
    $$CompaniesTableAnnotationComposer,
    $$CompaniesTableCreateCompanionBuilder,
    $$CompaniesTableUpdateCompanionBuilder,
    (Company, $$CompaniesTableReferences),
    Company,
    PrefetchHooks Function({bool usersRefs})>;
typedef $$UsersTableCreateCompanionBuilder = UsersCompanion Function({
  required String id,
  required String username,
  Value<String?> passwordHash,
  Value<String?> salt,
  Value<int?> iterations,
  Value<String?> userId,
  Value<String?> name,
  Value<String?> email,
  Value<String?> contactNo,
  Value<String?> permissions,
  Value<String?> companyId,
  Value<String?> status,
  Value<bool> isFirstLogin,
  Value<bool> isActive,
  Value<String?> createdAt,
  required String updatedAt,
  Value<int> rowid,
});
typedef $$UsersTableUpdateCompanionBuilder = UsersCompanion Function({
  Value<String> id,
  Value<String> username,
  Value<String?> passwordHash,
  Value<String?> salt,
  Value<int?> iterations,
  Value<String?> userId,
  Value<String?> name,
  Value<String?> email,
  Value<String?> contactNo,
  Value<String?> permissions,
  Value<String?> companyId,
  Value<String?> status,
  Value<bool> isFirstLogin,
  Value<bool> isActive,
  Value<String?> createdAt,
  Value<String> updatedAt,
  Value<int> rowid,
});

final class $$UsersTableReferences
    extends BaseReferences<_$AppDatabase, $UsersTable, User> {
  $$UsersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CompaniesTable _companyIdTable(_$AppDatabase db) => db.companies
      .createAlias($_aliasNameGenerator(db.users.companyId, db.companies.id));

  $$CompaniesTableProcessedTableManager? get companyId {
    final $_column = $_itemColumn<String>('company_id');
    if ($_column == null) return null;
    final manager = $$CompaniesTableTableManager($_db, $_db.companies)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_companyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$RemindersTable, List<Reminder>>
      _remindersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
          db.reminders,
          aliasName: $_aliasNameGenerator(db.users.id, db.reminders.agentId));

  $$RemindersTableProcessedTableManager get remindersRefs {
    final manager = $$RemindersTableTableManager($_db, $_db.reminders)
        .filter((f) => f.agentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_remindersRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$UsersTableFilterComposer extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get username => $composableBuilder(
      column: $table.username, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get passwordHash => $composableBuilder(
      column: $table.passwordHash, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get salt => $composableBuilder(
      column: $table.salt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get iterations => $composableBuilder(
      column: $table.iterations, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contactNo => $composableBuilder(
      column: $table.contactNo, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get permissions => $composableBuilder(
      column: $table.permissions, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isFirstLogin => $composableBuilder(
      column: $table.isFirstLogin, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  $$CompaniesTableFilterComposer get companyId {
    final $$CompaniesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.companyId,
        referencedTable: $db.companies,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CompaniesTableFilterComposer(
              $db: $db,
              $table: $db.companies,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> remindersRefs(
      Expression<bool> Function($$RemindersTableFilterComposer f) f) {
    final $$RemindersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.reminders,
        getReferencedColumn: (t) => t.agentId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RemindersTableFilterComposer(
              $db: $db,
              $table: $db.reminders,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$UsersTableOrderingComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get username => $composableBuilder(
      column: $table.username, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get passwordHash => $composableBuilder(
      column: $table.passwordHash,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get salt => $composableBuilder(
      column: $table.salt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get iterations => $composableBuilder(
      column: $table.iterations, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contactNo => $composableBuilder(
      column: $table.contactNo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get permissions => $composableBuilder(
      column: $table.permissions, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isFirstLogin => $composableBuilder(
      column: $table.isFirstLogin,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  $$CompaniesTableOrderingComposer get companyId {
    final $$CompaniesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.companyId,
        referencedTable: $db.companies,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CompaniesTableOrderingComposer(
              $db: $db,
              $table: $db.companies,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$UsersTableAnnotationComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<String> get passwordHash => $composableBuilder(
      column: $table.passwordHash, builder: (column) => column);

  GeneratedColumn<String> get salt =>
      $composableBuilder(column: $table.salt, builder: (column) => column);

  GeneratedColumn<int> get iterations => $composableBuilder(
      column: $table.iterations, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get contactNo =>
      $composableBuilder(column: $table.contactNo, builder: (column) => column);

  GeneratedColumn<String> get permissions => $composableBuilder(
      column: $table.permissions, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get isFirstLogin => $composableBuilder(
      column: $table.isFirstLogin, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$CompaniesTableAnnotationComposer get companyId {
    final $$CompaniesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.companyId,
        referencedTable: $db.companies,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CompaniesTableAnnotationComposer(
              $db: $db,
              $table: $db.companies,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> remindersRefs<T extends Object>(
      Expression<T> Function($$RemindersTableAnnotationComposer a) f) {
    final $$RemindersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.reminders,
        getReferencedColumn: (t) => t.agentId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RemindersTableAnnotationComposer(
              $db: $db,
              $table: $db.reminders,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$UsersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $UsersTable,
    User,
    $$UsersTableFilterComposer,
    $$UsersTableOrderingComposer,
    $$UsersTableAnnotationComposer,
    $$UsersTableCreateCompanionBuilder,
    $$UsersTableUpdateCompanionBuilder,
    (User, $$UsersTableReferences),
    User,
    PrefetchHooks Function({bool companyId, bool remindersRefs})> {
  $$UsersTableTableManager(_$AppDatabase db, $UsersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> username = const Value.absent(),
            Value<String?> passwordHash = const Value.absent(),
            Value<String?> salt = const Value.absent(),
            Value<int?> iterations = const Value.absent(),
            Value<String?> userId = const Value.absent(),
            Value<String?> name = const Value.absent(),
            Value<String?> email = const Value.absent(),
            Value<String?> contactNo = const Value.absent(),
            Value<String?> permissions = const Value.absent(),
            Value<String?> companyId = const Value.absent(),
            Value<String?> status = const Value.absent(),
            Value<bool> isFirstLogin = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<String?> createdAt = const Value.absent(),
            Value<String> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              UsersCompanion(
            id: id,
            username: username,
            passwordHash: passwordHash,
            salt: salt,
            iterations: iterations,
            userId: userId,
            name: name,
            email: email,
            contactNo: contactNo,
            permissions: permissions,
            companyId: companyId,
            status: status,
            isFirstLogin: isFirstLogin,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String username,
            Value<String?> passwordHash = const Value.absent(),
            Value<String?> salt = const Value.absent(),
            Value<int?> iterations = const Value.absent(),
            Value<String?> userId = const Value.absent(),
            Value<String?> name = const Value.absent(),
            Value<String?> email = const Value.absent(),
            Value<String?> contactNo = const Value.absent(),
            Value<String?> permissions = const Value.absent(),
            Value<String?> companyId = const Value.absent(),
            Value<String?> status = const Value.absent(),
            Value<bool> isFirstLogin = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<String?> createdAt = const Value.absent(),
            required String updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              UsersCompanion.insert(
            id: id,
            username: username,
            passwordHash: passwordHash,
            salt: salt,
            iterations: iterations,
            userId: userId,
            name: name,
            email: email,
            contactNo: contactNo,
            permissions: permissions,
            companyId: companyId,
            status: status,
            isFirstLogin: isFirstLogin,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$UsersTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({companyId = false, remindersRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (remindersRefs) db.reminders],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (companyId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.companyId,
                    referencedTable: $$UsersTableReferences._companyIdTable(db),
                    referencedColumn:
                        $$UsersTableReferences._companyIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (remindersRefs)
                    await $_getPrefetchedData<User, $UsersTable, Reminder>(
                        currentTable: table,
                        referencedTable:
                            $$UsersTableReferences._remindersRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$UsersTableReferences(db, table, p0).remindersRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.agentId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$UsersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $UsersTable,
    User,
    $$UsersTableFilterComposer,
    $$UsersTableOrderingComposer,
    $$UsersTableAnnotationComposer,
    $$UsersTableCreateCompanionBuilder,
    $$UsersTableUpdateCompanionBuilder,
    (User, $$UsersTableReferences),
    User,
    PrefetchHooks Function({bool companyId, bool remindersRefs})>;
typedef $$SocietiesTableCreateCompanionBuilder = SocietiesCompanion Function({
  required String id,
  required String name,
  Value<String?> companyId,
  Value<String?> metadata,
  Value<bool> isActive,
  required String updatedAt,
  Value<int> rowid,
});
typedef $$SocietiesTableUpdateCompanionBuilder = SocietiesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String?> companyId,
  Value<String?> metadata,
  Value<bool> isActive,
  Value<String> updatedAt,
  Value<int> rowid,
});

final class $$SocietiesTableReferences
    extends BaseReferences<_$AppDatabase, $SocietiesTable, Society> {
  $$SocietiesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$BlocksTable, List<Block>> _blocksRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.blocks,
          aliasName:
              $_aliasNameGenerator(db.societies.id, db.blocks.societyId));

  $$BlocksTableProcessedTableManager get blocksRefs {
    final manager = $$BlocksTableTableManager($_db, $_db.blocks)
        .filter((f) => f.societyId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_blocksRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$PropertiesTable, List<Property>>
      _propertiesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
          db.properties,
          aliasName:
              $_aliasNameGenerator(db.societies.id, db.properties.societyId));

  $$PropertiesTableProcessedTableManager get propertiesRefs {
    final manager = $$PropertiesTableTableManager($_db, $_db.properties)
        .filter((f) => f.societyId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_propertiesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$FilesTableTable, List<FilesTableData>>
      _filesTableRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
          db.filesTable,
          aliasName:
              $_aliasNameGenerator(db.societies.id, db.filesTable.societyId));

  $$FilesTableTableProcessedTableManager get filesTableRefs {
    final manager = $$FilesTableTableTableManager($_db, $_db.filesTable)
        .filter((f) => f.societyId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_filesTableRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$SocietiesTableFilterComposer
    extends Composer<_$AppDatabase, $SocietiesTable> {
  $$SocietiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get companyId => $composableBuilder(
      column: $table.companyId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get metadata => $composableBuilder(
      column: $table.metadata, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> blocksRefs(
      Expression<bool> Function($$BlocksTableFilterComposer f) f) {
    final $$BlocksTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.blocks,
        getReferencedColumn: (t) => t.societyId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BlocksTableFilterComposer(
              $db: $db,
              $table: $db.blocks,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> propertiesRefs(
      Expression<bool> Function($$PropertiesTableFilterComposer f) f) {
    final $$PropertiesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.properties,
        getReferencedColumn: (t) => t.societyId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PropertiesTableFilterComposer(
              $db: $db,
              $table: $db.properties,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> filesTableRefs(
      Expression<bool> Function($$FilesTableTableFilterComposer f) f) {
    final $$FilesTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.filesTable,
        getReferencedColumn: (t) => t.societyId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FilesTableTableFilterComposer(
              $db: $db,
              $table: $db.filesTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$SocietiesTableOrderingComposer
    extends Composer<_$AppDatabase, $SocietiesTable> {
  $$SocietiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get companyId => $composableBuilder(
      column: $table.companyId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get metadata => $composableBuilder(
      column: $table.metadata, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$SocietiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SocietiesTable> {
  $$SocietiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get metadata =>
      $composableBuilder(column: $table.metadata, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> blocksRefs<T extends Object>(
      Expression<T> Function($$BlocksTableAnnotationComposer a) f) {
    final $$BlocksTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.blocks,
        getReferencedColumn: (t) => t.societyId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BlocksTableAnnotationComposer(
              $db: $db,
              $table: $db.blocks,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> propertiesRefs<T extends Object>(
      Expression<T> Function($$PropertiesTableAnnotationComposer a) f) {
    final $$PropertiesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.properties,
        getReferencedColumn: (t) => t.societyId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PropertiesTableAnnotationComposer(
              $db: $db,
              $table: $db.properties,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> filesTableRefs<T extends Object>(
      Expression<T> Function($$FilesTableTableAnnotationComposer a) f) {
    final $$FilesTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.filesTable,
        getReferencedColumn: (t) => t.societyId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FilesTableTableAnnotationComposer(
              $db: $db,
              $table: $db.filesTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$SocietiesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SocietiesTable,
    Society,
    $$SocietiesTableFilterComposer,
    $$SocietiesTableOrderingComposer,
    $$SocietiesTableAnnotationComposer,
    $$SocietiesTableCreateCompanionBuilder,
    $$SocietiesTableUpdateCompanionBuilder,
    (Society, $$SocietiesTableReferences),
    Society,
    PrefetchHooks Function(
        {bool blocksRefs, bool propertiesRefs, bool filesTableRefs})> {
  $$SocietiesTableTableManager(_$AppDatabase db, $SocietiesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SocietiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SocietiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SocietiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> companyId = const Value.absent(),
            Value<String?> metadata = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<String> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SocietiesCompanion(
            id: id,
            name: name,
            companyId: companyId,
            metadata: metadata,
            isActive: isActive,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<String?> companyId = const Value.absent(),
            Value<String?> metadata = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            required String updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              SocietiesCompanion.insert(
            id: id,
            name: name,
            companyId: companyId,
            metadata: metadata,
            isActive: isActive,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$SocietiesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {blocksRefs = false,
              propertiesRefs = false,
              filesTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (blocksRefs) db.blocks,
                if (propertiesRefs) db.properties,
                if (filesTableRefs) db.filesTable
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (blocksRefs)
                    await $_getPrefetchedData<Society, $SocietiesTable, Block>(
                        currentTable: table,
                        referencedTable:
                            $$SocietiesTableReferences._blocksRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$SocietiesTableReferences(db, table, p0)
                                .blocksRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.societyId == item.id),
                        typedResults: items),
                  if (propertiesRefs)
                    await $_getPrefetchedData<Society, $SocietiesTable,
                            Property>(
                        currentTable: table,
                        referencedTable:
                            $$SocietiesTableReferences._propertiesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$SocietiesTableReferences(db, table, p0)
                                .propertiesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.societyId == item.id),
                        typedResults: items),
                  if (filesTableRefs)
                    await $_getPrefetchedData<Society, $SocietiesTable,
                            FilesTableData>(
                        currentTable: table,
                        referencedTable:
                            $$SocietiesTableReferences._filesTableRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$SocietiesTableReferences(db, table, p0)
                                .filesTableRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.societyId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$SocietiesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SocietiesTable,
    Society,
    $$SocietiesTableFilterComposer,
    $$SocietiesTableOrderingComposer,
    $$SocietiesTableAnnotationComposer,
    $$SocietiesTableCreateCompanionBuilder,
    $$SocietiesTableUpdateCompanionBuilder,
    (Society, $$SocietiesTableReferences),
    Society,
    PrefetchHooks Function(
        {bool blocksRefs, bool propertiesRefs, bool filesTableRefs})>;
typedef $$BlocksTableCreateCompanionBuilder = BlocksCompanion Function({
  required String id,
  required String societyId,
  required String name,
  Value<String?> companyId,
  Value<String?> metadata,
  Value<bool> isActive,
  required String updatedAt,
  Value<int> rowid,
});
typedef $$BlocksTableUpdateCompanionBuilder = BlocksCompanion Function({
  Value<String> id,
  Value<String> societyId,
  Value<String> name,
  Value<String?> companyId,
  Value<String?> metadata,
  Value<bool> isActive,
  Value<String> updatedAt,
  Value<int> rowid,
});

final class $$BlocksTableReferences
    extends BaseReferences<_$AppDatabase, $BlocksTable, Block> {
  $$BlocksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SocietiesTable _societyIdTable(_$AppDatabase db) => db.societies
      .createAlias($_aliasNameGenerator(db.blocks.societyId, db.societies.id));

  $$SocietiesTableProcessedTableManager get societyId {
    final $_column = $_itemColumn<String>('society_id')!;

    final manager = $$SocietiesTableTableManager($_db, $_db.societies)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_societyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$PropertiesTable, List<Property>>
      _propertiesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
          db.properties,
          aliasName: $_aliasNameGenerator(db.blocks.id, db.properties.blockId));

  $$PropertiesTableProcessedTableManager get propertiesRefs {
    final manager = $$PropertiesTableTableManager($_db, $_db.properties)
        .filter((f) => f.blockId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_propertiesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$FilesTableTable, List<FilesTableData>>
      _filesTableRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
          db.filesTable,
          aliasName: $_aliasNameGenerator(db.blocks.id, db.filesTable.blockId));

  $$FilesTableTableProcessedTableManager get filesTableRefs {
    final manager = $$FilesTableTableTableManager($_db, $_db.filesTable)
        .filter((f) => f.blockId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_filesTableRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$BlocksTableFilterComposer
    extends Composer<_$AppDatabase, $BlocksTable> {
  $$BlocksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get companyId => $composableBuilder(
      column: $table.companyId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get metadata => $composableBuilder(
      column: $table.metadata, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  $$SocietiesTableFilterComposer get societyId {
    final $$SocietiesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.societyId,
        referencedTable: $db.societies,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SocietiesTableFilterComposer(
              $db: $db,
              $table: $db.societies,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> propertiesRefs(
      Expression<bool> Function($$PropertiesTableFilterComposer f) f) {
    final $$PropertiesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.properties,
        getReferencedColumn: (t) => t.blockId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PropertiesTableFilterComposer(
              $db: $db,
              $table: $db.properties,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> filesTableRefs(
      Expression<bool> Function($$FilesTableTableFilterComposer f) f) {
    final $$FilesTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.filesTable,
        getReferencedColumn: (t) => t.blockId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FilesTableTableFilterComposer(
              $db: $db,
              $table: $db.filesTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$BlocksTableOrderingComposer
    extends Composer<_$AppDatabase, $BlocksTable> {
  $$BlocksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get companyId => $composableBuilder(
      column: $table.companyId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get metadata => $composableBuilder(
      column: $table.metadata, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  $$SocietiesTableOrderingComposer get societyId {
    final $$SocietiesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.societyId,
        referencedTable: $db.societies,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SocietiesTableOrderingComposer(
              $db: $db,
              $table: $db.societies,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$BlocksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BlocksTable> {
  $$BlocksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get metadata =>
      $composableBuilder(column: $table.metadata, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$SocietiesTableAnnotationComposer get societyId {
    final $$SocietiesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.societyId,
        referencedTable: $db.societies,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SocietiesTableAnnotationComposer(
              $db: $db,
              $table: $db.societies,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> propertiesRefs<T extends Object>(
      Expression<T> Function($$PropertiesTableAnnotationComposer a) f) {
    final $$PropertiesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.properties,
        getReferencedColumn: (t) => t.blockId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PropertiesTableAnnotationComposer(
              $db: $db,
              $table: $db.properties,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> filesTableRefs<T extends Object>(
      Expression<T> Function($$FilesTableTableAnnotationComposer a) f) {
    final $$FilesTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.filesTable,
        getReferencedColumn: (t) => t.blockId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FilesTableTableAnnotationComposer(
              $db: $db,
              $table: $db.filesTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$BlocksTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BlocksTable,
    Block,
    $$BlocksTableFilterComposer,
    $$BlocksTableOrderingComposer,
    $$BlocksTableAnnotationComposer,
    $$BlocksTableCreateCompanionBuilder,
    $$BlocksTableUpdateCompanionBuilder,
    (Block, $$BlocksTableReferences),
    Block,
    PrefetchHooks Function(
        {bool societyId, bool propertiesRefs, bool filesTableRefs})> {
  $$BlocksTableTableManager(_$AppDatabase db, $BlocksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BlocksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BlocksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BlocksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> societyId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> companyId = const Value.absent(),
            Value<String?> metadata = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<String> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BlocksCompanion(
            id: id,
            societyId: societyId,
            name: name,
            companyId: companyId,
            metadata: metadata,
            isActive: isActive,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String societyId,
            required String name,
            Value<String?> companyId = const Value.absent(),
            Value<String?> metadata = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            required String updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              BlocksCompanion.insert(
            id: id,
            societyId: societyId,
            name: name,
            companyId: companyId,
            metadata: metadata,
            isActive: isActive,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$BlocksTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: (
              {societyId = false,
              propertiesRefs = false,
              filesTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (propertiesRefs) db.properties,
                if (filesTableRefs) db.filesTable
              ],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (societyId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.societyId,
                    referencedTable:
                        $$BlocksTableReferences._societyIdTable(db),
                    referencedColumn:
                        $$BlocksTableReferences._societyIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (propertiesRefs)
                    await $_getPrefetchedData<Block, $BlocksTable, Property>(
                        currentTable: table,
                        referencedTable:
                            $$BlocksTableReferences._propertiesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$BlocksTableReferences(db, table, p0)
                                .propertiesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.blockId == item.id),
                        typedResults: items),
                  if (filesTableRefs)
                    await $_getPrefetchedData<Block, $BlocksTable,
                            FilesTableData>(
                        currentTable: table,
                        referencedTable:
                            $$BlocksTableReferences._filesTableRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$BlocksTableReferences(db, table, p0)
                                .filesTableRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.blockId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$BlocksTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BlocksTable,
    Block,
    $$BlocksTableFilterComposer,
    $$BlocksTableOrderingComposer,
    $$BlocksTableAnnotationComposer,
    $$BlocksTableCreateCompanionBuilder,
    $$BlocksTableUpdateCompanionBuilder,
    (Block, $$BlocksTableReferences),
    Block,
    PrefetchHooks Function(
        {bool societyId, bool propertiesRefs, bool filesTableRefs})>;
typedef $$PropertiesTableCreateCompanionBuilder = PropertiesCompanion Function({
  required String id,
  Value<String?> companyId,
  Value<String?> createdBy,
  required String propertyName,
  Value<int?> price,
  Value<String?> remarks,
  Value<String?> clientName,
  Value<String?> fileNo,
  Value<String?> referenceNo,
  Value<int?> demand,
  Value<String?> saleStatus,
  Value<String?> cnic,
  Value<String?> societyId,
  Value<String?> blockId,
  Value<bool> isActive,
  required String updatedAt,
  Value<int> rowid,
});
typedef $$PropertiesTableUpdateCompanionBuilder = PropertiesCompanion Function({
  Value<String> id,
  Value<String?> companyId,
  Value<String?> createdBy,
  Value<String> propertyName,
  Value<int?> price,
  Value<String?> remarks,
  Value<String?> clientName,
  Value<String?> fileNo,
  Value<String?> referenceNo,
  Value<int?> demand,
  Value<String?> saleStatus,
  Value<String?> cnic,
  Value<String?> societyId,
  Value<String?> blockId,
  Value<bool> isActive,
  Value<String> updatedAt,
  Value<int> rowid,
});

final class $$PropertiesTableReferences
    extends BaseReferences<_$AppDatabase, $PropertiesTable, Property> {
  $$PropertiesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SocietiesTable _societyIdTable(_$AppDatabase db) =>
      db.societies.createAlias(
          $_aliasNameGenerator(db.properties.societyId, db.societies.id));

  $$SocietiesTableProcessedTableManager? get societyId {
    final $_column = $_itemColumn<String>('society_id');
    if ($_column == null) return null;
    final manager = $$SocietiesTableTableManager($_db, $_db.societies)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_societyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $BlocksTable _blockIdTable(_$AppDatabase db) => db.blocks
      .createAlias($_aliasNameGenerator(db.properties.blockId, db.blocks.id));

  $$BlocksTableProcessedTableManager? get blockId {
    final $_column = $_itemColumn<String>('block_id');
    if ($_column == null) return null;
    final manager = $$BlocksTableTableManager($_db, $_db.blocks)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_blockIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$PropertyCommentsTable, List<PropertyComment>>
      _propertyCommentsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.propertyComments,
              aliasName: $_aliasNameGenerator(
                  db.properties.id, db.propertyComments.parentId));

  $$PropertyCommentsTableProcessedTableManager get propertyCommentsRefs {
    final manager = $$PropertyCommentsTableTableManager(
            $_db, $_db.propertyComments)
        .filter((f) => f.parentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_propertyCommentsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$PropertiesTableFilterComposer
    extends Composer<_$AppDatabase, $PropertiesTable> {
  $$PropertiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get companyId => $composableBuilder(
      column: $table.companyId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdBy => $composableBuilder(
      column: $table.createdBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get propertyName => $composableBuilder(
      column: $table.propertyName, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get price => $composableBuilder(
      column: $table.price, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get remarks => $composableBuilder(
      column: $table.remarks, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get clientName => $composableBuilder(
      column: $table.clientName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fileNo => $composableBuilder(
      column: $table.fileNo, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get referenceNo => $composableBuilder(
      column: $table.referenceNo, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get demand => $composableBuilder(
      column: $table.demand, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get saleStatus => $composableBuilder(
      column: $table.saleStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cnic => $composableBuilder(
      column: $table.cnic, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  $$SocietiesTableFilterComposer get societyId {
    final $$SocietiesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.societyId,
        referencedTable: $db.societies,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SocietiesTableFilterComposer(
              $db: $db,
              $table: $db.societies,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$BlocksTableFilterComposer get blockId {
    final $$BlocksTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.blockId,
        referencedTable: $db.blocks,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BlocksTableFilterComposer(
              $db: $db,
              $table: $db.blocks,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> propertyCommentsRefs(
      Expression<bool> Function($$PropertyCommentsTableFilterComposer f) f) {
    final $$PropertyCommentsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.propertyComments,
        getReferencedColumn: (t) => t.parentId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PropertyCommentsTableFilterComposer(
              $db: $db,
              $table: $db.propertyComments,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$PropertiesTableOrderingComposer
    extends Composer<_$AppDatabase, $PropertiesTable> {
  $$PropertiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get companyId => $composableBuilder(
      column: $table.companyId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdBy => $composableBuilder(
      column: $table.createdBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get propertyName => $composableBuilder(
      column: $table.propertyName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get price => $composableBuilder(
      column: $table.price, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get remarks => $composableBuilder(
      column: $table.remarks, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get clientName => $composableBuilder(
      column: $table.clientName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fileNo => $composableBuilder(
      column: $table.fileNo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get referenceNo => $composableBuilder(
      column: $table.referenceNo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get demand => $composableBuilder(
      column: $table.demand, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get saleStatus => $composableBuilder(
      column: $table.saleStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cnic => $composableBuilder(
      column: $table.cnic, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  $$SocietiesTableOrderingComposer get societyId {
    final $$SocietiesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.societyId,
        referencedTable: $db.societies,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SocietiesTableOrderingComposer(
              $db: $db,
              $table: $db.societies,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$BlocksTableOrderingComposer get blockId {
    final $$BlocksTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.blockId,
        referencedTable: $db.blocks,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BlocksTableOrderingComposer(
              $db: $db,
              $table: $db.blocks,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PropertiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PropertiesTable> {
  $$PropertiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get propertyName => $composableBuilder(
      column: $table.propertyName, builder: (column) => column);

  GeneratedColumn<int> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<String> get remarks =>
      $composableBuilder(column: $table.remarks, builder: (column) => column);

  GeneratedColumn<String> get clientName => $composableBuilder(
      column: $table.clientName, builder: (column) => column);

  GeneratedColumn<String> get fileNo =>
      $composableBuilder(column: $table.fileNo, builder: (column) => column);

  GeneratedColumn<String> get referenceNo => $composableBuilder(
      column: $table.referenceNo, builder: (column) => column);

  GeneratedColumn<int> get demand =>
      $composableBuilder(column: $table.demand, builder: (column) => column);

  GeneratedColumn<String> get saleStatus => $composableBuilder(
      column: $table.saleStatus, builder: (column) => column);

  GeneratedColumn<String> get cnic =>
      $composableBuilder(column: $table.cnic, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$SocietiesTableAnnotationComposer get societyId {
    final $$SocietiesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.societyId,
        referencedTable: $db.societies,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SocietiesTableAnnotationComposer(
              $db: $db,
              $table: $db.societies,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$BlocksTableAnnotationComposer get blockId {
    final $$BlocksTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.blockId,
        referencedTable: $db.blocks,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BlocksTableAnnotationComposer(
              $db: $db,
              $table: $db.blocks,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> propertyCommentsRefs<T extends Object>(
      Expression<T> Function($$PropertyCommentsTableAnnotationComposer a) f) {
    final $$PropertyCommentsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.propertyComments,
        getReferencedColumn: (t) => t.parentId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PropertyCommentsTableAnnotationComposer(
              $db: $db,
              $table: $db.propertyComments,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$PropertiesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PropertiesTable,
    Property,
    $$PropertiesTableFilterComposer,
    $$PropertiesTableOrderingComposer,
    $$PropertiesTableAnnotationComposer,
    $$PropertiesTableCreateCompanionBuilder,
    $$PropertiesTableUpdateCompanionBuilder,
    (Property, $$PropertiesTableReferences),
    Property,
    PrefetchHooks Function(
        {bool societyId, bool blockId, bool propertyCommentsRefs})> {
  $$PropertiesTableTableManager(_$AppDatabase db, $PropertiesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PropertiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PropertiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PropertiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String?> companyId = const Value.absent(),
            Value<String?> createdBy = const Value.absent(),
            Value<String> propertyName = const Value.absent(),
            Value<int?> price = const Value.absent(),
            Value<String?> remarks = const Value.absent(),
            Value<String?> clientName = const Value.absent(),
            Value<String?> fileNo = const Value.absent(),
            Value<String?> referenceNo = const Value.absent(),
            Value<int?> demand = const Value.absent(),
            Value<String?> saleStatus = const Value.absent(),
            Value<String?> cnic = const Value.absent(),
            Value<String?> societyId = const Value.absent(),
            Value<String?> blockId = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<String> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PropertiesCompanion(
            id: id,
            companyId: companyId,
            createdBy: createdBy,
            propertyName: propertyName,
            price: price,
            remarks: remarks,
            clientName: clientName,
            fileNo: fileNo,
            referenceNo: referenceNo,
            demand: demand,
            saleStatus: saleStatus,
            cnic: cnic,
            societyId: societyId,
            blockId: blockId,
            isActive: isActive,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String?> companyId = const Value.absent(),
            Value<String?> createdBy = const Value.absent(),
            required String propertyName,
            Value<int?> price = const Value.absent(),
            Value<String?> remarks = const Value.absent(),
            Value<String?> clientName = const Value.absent(),
            Value<String?> fileNo = const Value.absent(),
            Value<String?> referenceNo = const Value.absent(),
            Value<int?> demand = const Value.absent(),
            Value<String?> saleStatus = const Value.absent(),
            Value<String?> cnic = const Value.absent(),
            Value<String?> societyId = const Value.absent(),
            Value<String?> blockId = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            required String updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              PropertiesCompanion.insert(
            id: id,
            companyId: companyId,
            createdBy: createdBy,
            propertyName: propertyName,
            price: price,
            remarks: remarks,
            clientName: clientName,
            fileNo: fileNo,
            referenceNo: referenceNo,
            demand: demand,
            saleStatus: saleStatus,
            cnic: cnic,
            societyId: societyId,
            blockId: blockId,
            isActive: isActive,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$PropertiesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {societyId = false,
              blockId = false,
              propertyCommentsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (propertyCommentsRefs) db.propertyComments
              ],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (societyId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.societyId,
                    referencedTable:
                        $$PropertiesTableReferences._societyIdTable(db),
                    referencedColumn:
                        $$PropertiesTableReferences._societyIdTable(db).id,
                  ) as T;
                }
                if (blockId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.blockId,
                    referencedTable:
                        $$PropertiesTableReferences._blockIdTable(db),
                    referencedColumn:
                        $$PropertiesTableReferences._blockIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (propertyCommentsRefs)
                    await $_getPrefetchedData<Property, $PropertiesTable,
                            PropertyComment>(
                        currentTable: table,
                        referencedTable: $$PropertiesTableReferences
                            ._propertyCommentsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$PropertiesTableReferences(db, table, p0)
                                .propertyCommentsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.parentId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$PropertiesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PropertiesTable,
    Property,
    $$PropertiesTableFilterComposer,
    $$PropertiesTableOrderingComposer,
    $$PropertiesTableAnnotationComposer,
    $$PropertiesTableCreateCompanionBuilder,
    $$PropertiesTableUpdateCompanionBuilder,
    (Property, $$PropertiesTableReferences),
    Property,
    PrefetchHooks Function(
        {bool societyId, bool blockId, bool propertyCommentsRefs})>;
typedef $$PropertyCommentsTableCreateCompanionBuilder
    = PropertyCommentsCompanion Function({
  required String id,
  required String parentId,
  Value<String?> companyId,
  required String comment,
  required String updatedAt,
  Value<int> rowid,
});
typedef $$PropertyCommentsTableUpdateCompanionBuilder
    = PropertyCommentsCompanion Function({
  Value<String> id,
  Value<String> parentId,
  Value<String?> companyId,
  Value<String> comment,
  Value<String> updatedAt,
  Value<int> rowid,
});

final class $$PropertyCommentsTableReferences extends BaseReferences<
    _$AppDatabase, $PropertyCommentsTable, PropertyComment> {
  $$PropertyCommentsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $PropertiesTable _parentIdTable(_$AppDatabase db) =>
      db.properties.createAlias(
          $_aliasNameGenerator(db.propertyComments.parentId, db.properties.id));

  $$PropertiesTableProcessedTableManager get parentId {
    final $_column = $_itemColumn<String>('parent_id')!;

    final manager = $$PropertiesTableTableManager($_db, $_db.properties)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$PropertyCommentsTableFilterComposer
    extends Composer<_$AppDatabase, $PropertyCommentsTable> {
  $$PropertyCommentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get companyId => $composableBuilder(
      column: $table.companyId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get comment => $composableBuilder(
      column: $table.comment, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  $$PropertiesTableFilterComposer get parentId {
    final $$PropertiesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.parentId,
        referencedTable: $db.properties,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PropertiesTableFilterComposer(
              $db: $db,
              $table: $db.properties,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PropertyCommentsTableOrderingComposer
    extends Composer<_$AppDatabase, $PropertyCommentsTable> {
  $$PropertyCommentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get companyId => $composableBuilder(
      column: $table.companyId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get comment => $composableBuilder(
      column: $table.comment, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  $$PropertiesTableOrderingComposer get parentId {
    final $$PropertiesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.parentId,
        referencedTable: $db.properties,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PropertiesTableOrderingComposer(
              $db: $db,
              $table: $db.properties,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PropertyCommentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PropertyCommentsTable> {
  $$PropertyCommentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get comment =>
      $composableBuilder(column: $table.comment, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$PropertiesTableAnnotationComposer get parentId {
    final $$PropertiesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.parentId,
        referencedTable: $db.properties,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PropertiesTableAnnotationComposer(
              $db: $db,
              $table: $db.properties,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PropertyCommentsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PropertyCommentsTable,
    PropertyComment,
    $$PropertyCommentsTableFilterComposer,
    $$PropertyCommentsTableOrderingComposer,
    $$PropertyCommentsTableAnnotationComposer,
    $$PropertyCommentsTableCreateCompanionBuilder,
    $$PropertyCommentsTableUpdateCompanionBuilder,
    (PropertyComment, $$PropertyCommentsTableReferences),
    PropertyComment,
    PrefetchHooks Function({bool parentId})> {
  $$PropertyCommentsTableTableManager(
      _$AppDatabase db, $PropertyCommentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PropertyCommentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PropertyCommentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PropertyCommentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> parentId = const Value.absent(),
            Value<String?> companyId = const Value.absent(),
            Value<String> comment = const Value.absent(),
            Value<String> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PropertyCommentsCompanion(
            id: id,
            parentId: parentId,
            companyId: companyId,
            comment: comment,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String parentId,
            Value<String?> companyId = const Value.absent(),
            required String comment,
            required String updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              PropertyCommentsCompanion.insert(
            id: id,
            parentId: parentId,
            companyId: companyId,
            comment: comment,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$PropertyCommentsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({parentId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (parentId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.parentId,
                    referencedTable:
                        $$PropertyCommentsTableReferences._parentIdTable(db),
                    referencedColumn:
                        $$PropertyCommentsTableReferences._parentIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$PropertyCommentsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PropertyCommentsTable,
    PropertyComment,
    $$PropertyCommentsTableFilterComposer,
    $$PropertyCommentsTableOrderingComposer,
    $$PropertyCommentsTableAnnotationComposer,
    $$PropertyCommentsTableCreateCompanionBuilder,
    $$PropertyCommentsTableUpdateCompanionBuilder,
    (PropertyComment, $$PropertyCommentsTableReferences),
    PropertyComment,
    PrefetchHooks Function({bool parentId})>;
typedef $$FilesTableTableCreateCompanionBuilder = FilesTableCompanion Function({
  required String id,
  Value<String?> companyId,
  Value<String?> createdBy,
  required String name,
  Value<String?> clientName,
  Value<String?> fileNo,
  Value<String?> referenceNo,
  Value<int?> demand,
  Value<String?> saleStatus,
  Value<String?> mobileNo,
  Value<String?> cnic,
  Value<String?> societyId,
  Value<String?> blockId,
  Value<String?> path,
  Value<String?> remarks,
  Value<bool> isActive,
  required String updatedAt,
  Value<int> rowid,
});
typedef $$FilesTableTableUpdateCompanionBuilder = FilesTableCompanion Function({
  Value<String> id,
  Value<String?> companyId,
  Value<String?> createdBy,
  Value<String> name,
  Value<String?> clientName,
  Value<String?> fileNo,
  Value<String?> referenceNo,
  Value<int?> demand,
  Value<String?> saleStatus,
  Value<String?> mobileNo,
  Value<String?> cnic,
  Value<String?> societyId,
  Value<String?> blockId,
  Value<String?> path,
  Value<String?> remarks,
  Value<bool> isActive,
  Value<String> updatedAt,
  Value<int> rowid,
});

final class $$FilesTableTableReferences
    extends BaseReferences<_$AppDatabase, $FilesTableTable, FilesTableData> {
  $$FilesTableTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SocietiesTable _societyIdTable(_$AppDatabase db) =>
      db.societies.createAlias(
          $_aliasNameGenerator(db.filesTable.societyId, db.societies.id));

  $$SocietiesTableProcessedTableManager? get societyId {
    final $_column = $_itemColumn<String>('society_id');
    if ($_column == null) return null;
    final manager = $$SocietiesTableTableManager($_db, $_db.societies)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_societyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $BlocksTable _blockIdTable(_$AppDatabase db) => db.blocks
      .createAlias($_aliasNameGenerator(db.filesTable.blockId, db.blocks.id));

  $$BlocksTableProcessedTableManager? get blockId {
    final $_column = $_itemColumn<String>('block_id');
    if ($_column == null) return null;
    final manager = $$BlocksTableTableManager($_db, $_db.blocks)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_blockIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$FileCommentsTable, List<FileComment>>
      _fileCommentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
          db.fileComments,
          aliasName:
              $_aliasNameGenerator(db.filesTable.id, db.fileComments.parentId));

  $$FileCommentsTableProcessedTableManager get fileCommentsRefs {
    final manager = $$FileCommentsTableTableManager($_db, $_db.fileComments)
        .filter((f) => f.parentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_fileCommentsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$FilesTableTableFilterComposer
    extends Composer<_$AppDatabase, $FilesTableTable> {
  $$FilesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get companyId => $composableBuilder(
      column: $table.companyId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdBy => $composableBuilder(
      column: $table.createdBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get clientName => $composableBuilder(
      column: $table.clientName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fileNo => $composableBuilder(
      column: $table.fileNo, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get referenceNo => $composableBuilder(
      column: $table.referenceNo, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get demand => $composableBuilder(
      column: $table.demand, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get saleStatus => $composableBuilder(
      column: $table.saleStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mobileNo => $composableBuilder(
      column: $table.mobileNo, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cnic => $composableBuilder(
      column: $table.cnic, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get path => $composableBuilder(
      column: $table.path, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get remarks => $composableBuilder(
      column: $table.remarks, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  $$SocietiesTableFilterComposer get societyId {
    final $$SocietiesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.societyId,
        referencedTable: $db.societies,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SocietiesTableFilterComposer(
              $db: $db,
              $table: $db.societies,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$BlocksTableFilterComposer get blockId {
    final $$BlocksTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.blockId,
        referencedTable: $db.blocks,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BlocksTableFilterComposer(
              $db: $db,
              $table: $db.blocks,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> fileCommentsRefs(
      Expression<bool> Function($$FileCommentsTableFilterComposer f) f) {
    final $$FileCommentsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.fileComments,
        getReferencedColumn: (t) => t.parentId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FileCommentsTableFilterComposer(
              $db: $db,
              $table: $db.fileComments,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$FilesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $FilesTableTable> {
  $$FilesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get companyId => $composableBuilder(
      column: $table.companyId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdBy => $composableBuilder(
      column: $table.createdBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get clientName => $composableBuilder(
      column: $table.clientName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fileNo => $composableBuilder(
      column: $table.fileNo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get referenceNo => $composableBuilder(
      column: $table.referenceNo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get demand => $composableBuilder(
      column: $table.demand, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get saleStatus => $composableBuilder(
      column: $table.saleStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mobileNo => $composableBuilder(
      column: $table.mobileNo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cnic => $composableBuilder(
      column: $table.cnic, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get path => $composableBuilder(
      column: $table.path, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get remarks => $composableBuilder(
      column: $table.remarks, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  $$SocietiesTableOrderingComposer get societyId {
    final $$SocietiesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.societyId,
        referencedTable: $db.societies,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SocietiesTableOrderingComposer(
              $db: $db,
              $table: $db.societies,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$BlocksTableOrderingComposer get blockId {
    final $$BlocksTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.blockId,
        referencedTable: $db.blocks,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BlocksTableOrderingComposer(
              $db: $db,
              $table: $db.blocks,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$FilesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $FilesTableTable> {
  $$FilesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get clientName => $composableBuilder(
      column: $table.clientName, builder: (column) => column);

  GeneratedColumn<String> get fileNo =>
      $composableBuilder(column: $table.fileNo, builder: (column) => column);

  GeneratedColumn<String> get referenceNo => $composableBuilder(
      column: $table.referenceNo, builder: (column) => column);

  GeneratedColumn<int> get demand =>
      $composableBuilder(column: $table.demand, builder: (column) => column);

  GeneratedColumn<String> get saleStatus => $composableBuilder(
      column: $table.saleStatus, builder: (column) => column);

  GeneratedColumn<String> get mobileNo =>
      $composableBuilder(column: $table.mobileNo, builder: (column) => column);

  GeneratedColumn<String> get cnic =>
      $composableBuilder(column: $table.cnic, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get remarks =>
      $composableBuilder(column: $table.remarks, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$SocietiesTableAnnotationComposer get societyId {
    final $$SocietiesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.societyId,
        referencedTable: $db.societies,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SocietiesTableAnnotationComposer(
              $db: $db,
              $table: $db.societies,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$BlocksTableAnnotationComposer get blockId {
    final $$BlocksTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.blockId,
        referencedTable: $db.blocks,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BlocksTableAnnotationComposer(
              $db: $db,
              $table: $db.blocks,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> fileCommentsRefs<T extends Object>(
      Expression<T> Function($$FileCommentsTableAnnotationComposer a) f) {
    final $$FileCommentsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.fileComments,
        getReferencedColumn: (t) => t.parentId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FileCommentsTableAnnotationComposer(
              $db: $db,
              $table: $db.fileComments,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$FilesTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $FilesTableTable,
    FilesTableData,
    $$FilesTableTableFilterComposer,
    $$FilesTableTableOrderingComposer,
    $$FilesTableTableAnnotationComposer,
    $$FilesTableTableCreateCompanionBuilder,
    $$FilesTableTableUpdateCompanionBuilder,
    (FilesTableData, $$FilesTableTableReferences),
    FilesTableData,
    PrefetchHooks Function(
        {bool societyId, bool blockId, bool fileCommentsRefs})> {
  $$FilesTableTableTableManager(_$AppDatabase db, $FilesTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FilesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FilesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FilesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String?> companyId = const Value.absent(),
            Value<String?> createdBy = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> clientName = const Value.absent(),
            Value<String?> fileNo = const Value.absent(),
            Value<String?> referenceNo = const Value.absent(),
            Value<int?> demand = const Value.absent(),
            Value<String?> saleStatus = const Value.absent(),
            Value<String?> mobileNo = const Value.absent(),
            Value<String?> cnic = const Value.absent(),
            Value<String?> societyId = const Value.absent(),
            Value<String?> blockId = const Value.absent(),
            Value<String?> path = const Value.absent(),
            Value<String?> remarks = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<String> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FilesTableCompanion(
            id: id,
            companyId: companyId,
            createdBy: createdBy,
            name: name,
            clientName: clientName,
            fileNo: fileNo,
            referenceNo: referenceNo,
            demand: demand,
            saleStatus: saleStatus,
            mobileNo: mobileNo,
            cnic: cnic,
            societyId: societyId,
            blockId: blockId,
            path: path,
            remarks: remarks,
            isActive: isActive,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String?> companyId = const Value.absent(),
            Value<String?> createdBy = const Value.absent(),
            required String name,
            Value<String?> clientName = const Value.absent(),
            Value<String?> fileNo = const Value.absent(),
            Value<String?> referenceNo = const Value.absent(),
            Value<int?> demand = const Value.absent(),
            Value<String?> saleStatus = const Value.absent(),
            Value<String?> mobileNo = const Value.absent(),
            Value<String?> cnic = const Value.absent(),
            Value<String?> societyId = const Value.absent(),
            Value<String?> blockId = const Value.absent(),
            Value<String?> path = const Value.absent(),
            Value<String?> remarks = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            required String updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              FilesTableCompanion.insert(
            id: id,
            companyId: companyId,
            createdBy: createdBy,
            name: name,
            clientName: clientName,
            fileNo: fileNo,
            referenceNo: referenceNo,
            demand: demand,
            saleStatus: saleStatus,
            mobileNo: mobileNo,
            cnic: cnic,
            societyId: societyId,
            blockId: blockId,
            path: path,
            remarks: remarks,
            isActive: isActive,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$FilesTableTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {societyId = false, blockId = false, fileCommentsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (fileCommentsRefs) db.fileComments],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (societyId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.societyId,
                    referencedTable:
                        $$FilesTableTableReferences._societyIdTable(db),
                    referencedColumn:
                        $$FilesTableTableReferences._societyIdTable(db).id,
                  ) as T;
                }
                if (blockId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.blockId,
                    referencedTable:
                        $$FilesTableTableReferences._blockIdTable(db),
                    referencedColumn:
                        $$FilesTableTableReferences._blockIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (fileCommentsRefs)
                    await $_getPrefetchedData<FilesTableData, $FilesTableTable,
                            FileComment>(
                        currentTable: table,
                        referencedTable: $$FilesTableTableReferences
                            ._fileCommentsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$FilesTableTableReferences(db, table, p0)
                                .fileCommentsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.parentId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$FilesTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $FilesTableTable,
    FilesTableData,
    $$FilesTableTableFilterComposer,
    $$FilesTableTableOrderingComposer,
    $$FilesTableTableAnnotationComposer,
    $$FilesTableTableCreateCompanionBuilder,
    $$FilesTableTableUpdateCompanionBuilder,
    (FilesTableData, $$FilesTableTableReferences),
    FilesTableData,
    PrefetchHooks Function(
        {bool societyId, bool blockId, bool fileCommentsRefs})>;
typedef $$FileCommentsTableCreateCompanionBuilder = FileCommentsCompanion
    Function({
  required String id,
  required String parentId,
  Value<String?> companyId,
  required String comment,
  required String updatedAt,
  Value<int> rowid,
});
typedef $$FileCommentsTableUpdateCompanionBuilder = FileCommentsCompanion
    Function({
  Value<String> id,
  Value<String> parentId,
  Value<String?> companyId,
  Value<String> comment,
  Value<String> updatedAt,
  Value<int> rowid,
});

final class $$FileCommentsTableReferences
    extends BaseReferences<_$AppDatabase, $FileCommentsTable, FileComment> {
  $$FileCommentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FilesTableTable _parentIdTable(_$AppDatabase db) =>
      db.filesTable.createAlias(
          $_aliasNameGenerator(db.fileComments.parentId, db.filesTable.id));

  $$FilesTableTableProcessedTableManager get parentId {
    final $_column = $_itemColumn<String>('parent_id')!;

    final manager = $$FilesTableTableTableManager($_db, $_db.filesTable)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$FileCommentsTableFilterComposer
    extends Composer<_$AppDatabase, $FileCommentsTable> {
  $$FileCommentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get companyId => $composableBuilder(
      column: $table.companyId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get comment => $composableBuilder(
      column: $table.comment, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  $$FilesTableTableFilterComposer get parentId {
    final $$FilesTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.parentId,
        referencedTable: $db.filesTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FilesTableTableFilterComposer(
              $db: $db,
              $table: $db.filesTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$FileCommentsTableOrderingComposer
    extends Composer<_$AppDatabase, $FileCommentsTable> {
  $$FileCommentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get companyId => $composableBuilder(
      column: $table.companyId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get comment => $composableBuilder(
      column: $table.comment, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  $$FilesTableTableOrderingComposer get parentId {
    final $$FilesTableTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.parentId,
        referencedTable: $db.filesTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FilesTableTableOrderingComposer(
              $db: $db,
              $table: $db.filesTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$FileCommentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FileCommentsTable> {
  $$FileCommentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get comment =>
      $composableBuilder(column: $table.comment, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$FilesTableTableAnnotationComposer get parentId {
    final $$FilesTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.parentId,
        referencedTable: $db.filesTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FilesTableTableAnnotationComposer(
              $db: $db,
              $table: $db.filesTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$FileCommentsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $FileCommentsTable,
    FileComment,
    $$FileCommentsTableFilterComposer,
    $$FileCommentsTableOrderingComposer,
    $$FileCommentsTableAnnotationComposer,
    $$FileCommentsTableCreateCompanionBuilder,
    $$FileCommentsTableUpdateCompanionBuilder,
    (FileComment, $$FileCommentsTableReferences),
    FileComment,
    PrefetchHooks Function({bool parentId})> {
  $$FileCommentsTableTableManager(_$AppDatabase db, $FileCommentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FileCommentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FileCommentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FileCommentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> parentId = const Value.absent(),
            Value<String?> companyId = const Value.absent(),
            Value<String> comment = const Value.absent(),
            Value<String> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FileCommentsCompanion(
            id: id,
            parentId: parentId,
            companyId: companyId,
            comment: comment,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String parentId,
            Value<String?> companyId = const Value.absent(),
            required String comment,
            required String updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              FileCommentsCompanion.insert(
            id: id,
            parentId: parentId,
            companyId: companyId,
            comment: comment,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$FileCommentsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({parentId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (parentId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.parentId,
                    referencedTable:
                        $$FileCommentsTableReferences._parentIdTable(db),
                    referencedColumn:
                        $$FileCommentsTableReferences._parentIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$FileCommentsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $FileCommentsTable,
    FileComment,
    $$FileCommentsTableFilterComposer,
    $$FileCommentsTableOrderingComposer,
    $$FileCommentsTableAnnotationComposer,
    $$FileCommentsTableCreateCompanionBuilder,
    $$FileCommentsTableUpdateCompanionBuilder,
    (FileComment, $$FileCommentsTableReferences),
    FileComment,
    PrefetchHooks Function({bool parentId})>;
typedef $$RentalItemsTableCreateCompanionBuilder = RentalItemsCompanion
    Function({
  required String id,
  Value<String?> companyId,
  Value<String?> createdBy,
  required String name,
  Value<int?> price,
  Value<String?> remarks,
  Value<String?> location,
  Value<String?> ownerName,
  Value<String?> contactNo,
  Value<String?> cnic,
  Value<int?> security,
  Value<String?> saleStatus,
  Value<bool> isActive,
  required String updatedAt,
  Value<int> rowid,
});
typedef $$RentalItemsTableUpdateCompanionBuilder = RentalItemsCompanion
    Function({
  Value<String> id,
  Value<String?> companyId,
  Value<String?> createdBy,
  Value<String> name,
  Value<int?> price,
  Value<String?> remarks,
  Value<String?> location,
  Value<String?> ownerName,
  Value<String?> contactNo,
  Value<String?> cnic,
  Value<int?> security,
  Value<String?> saleStatus,
  Value<bool> isActive,
  Value<String> updatedAt,
  Value<int> rowid,
});

final class $$RentalItemsTableReferences
    extends BaseReferences<_$AppDatabase, $RentalItemsTable, RentalItem> {
  $$RentalItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$RentalCommentsTable, List<RentalComment>>
      _rentalCommentsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.rentalComments,
              aliasName: $_aliasNameGenerator(
                  db.rentalItems.id, db.rentalComments.parentId));

  $$RentalCommentsTableProcessedTableManager get rentalCommentsRefs {
    final manager = $$RentalCommentsTableTableManager($_db, $_db.rentalComments)
        .filter((f) => f.parentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_rentalCommentsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$RentalItemsTableFilterComposer
    extends Composer<_$AppDatabase, $RentalItemsTable> {
  $$RentalItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get companyId => $composableBuilder(
      column: $table.companyId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdBy => $composableBuilder(
      column: $table.createdBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get price => $composableBuilder(
      column: $table.price, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get remarks => $composableBuilder(
      column: $table.remarks, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get location => $composableBuilder(
      column: $table.location, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ownerName => $composableBuilder(
      column: $table.ownerName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contactNo => $composableBuilder(
      column: $table.contactNo, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cnic => $composableBuilder(
      column: $table.cnic, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get security => $composableBuilder(
      column: $table.security, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get saleStatus => $composableBuilder(
      column: $table.saleStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> rentalCommentsRefs(
      Expression<bool> Function($$RentalCommentsTableFilterComposer f) f) {
    final $$RentalCommentsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.rentalComments,
        getReferencedColumn: (t) => t.parentId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RentalCommentsTableFilterComposer(
              $db: $db,
              $table: $db.rentalComments,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$RentalItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $RentalItemsTable> {
  $$RentalItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get companyId => $composableBuilder(
      column: $table.companyId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdBy => $composableBuilder(
      column: $table.createdBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get price => $composableBuilder(
      column: $table.price, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get remarks => $composableBuilder(
      column: $table.remarks, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get location => $composableBuilder(
      column: $table.location, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ownerName => $composableBuilder(
      column: $table.ownerName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contactNo => $composableBuilder(
      column: $table.contactNo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cnic => $composableBuilder(
      column: $table.cnic, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get security => $composableBuilder(
      column: $table.security, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get saleStatus => $composableBuilder(
      column: $table.saleStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$RentalItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RentalItemsTable> {
  $$RentalItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<String> get remarks =>
      $composableBuilder(column: $table.remarks, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<String> get ownerName =>
      $composableBuilder(column: $table.ownerName, builder: (column) => column);

  GeneratedColumn<String> get contactNo =>
      $composableBuilder(column: $table.contactNo, builder: (column) => column);

  GeneratedColumn<String> get cnic =>
      $composableBuilder(column: $table.cnic, builder: (column) => column);

  GeneratedColumn<int> get security =>
      $composableBuilder(column: $table.security, builder: (column) => column);

  GeneratedColumn<String> get saleStatus => $composableBuilder(
      column: $table.saleStatus, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> rentalCommentsRefs<T extends Object>(
      Expression<T> Function($$RentalCommentsTableAnnotationComposer a) f) {
    final $$RentalCommentsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.rentalComments,
        getReferencedColumn: (t) => t.parentId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RentalCommentsTableAnnotationComposer(
              $db: $db,
              $table: $db.rentalComments,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$RentalItemsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RentalItemsTable,
    RentalItem,
    $$RentalItemsTableFilterComposer,
    $$RentalItemsTableOrderingComposer,
    $$RentalItemsTableAnnotationComposer,
    $$RentalItemsTableCreateCompanionBuilder,
    $$RentalItemsTableUpdateCompanionBuilder,
    (RentalItem, $$RentalItemsTableReferences),
    RentalItem,
    PrefetchHooks Function({bool rentalCommentsRefs})> {
  $$RentalItemsTableTableManager(_$AppDatabase db, $RentalItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RentalItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RentalItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RentalItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String?> companyId = const Value.absent(),
            Value<String?> createdBy = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int?> price = const Value.absent(),
            Value<String?> remarks = const Value.absent(),
            Value<String?> location = const Value.absent(),
            Value<String?> ownerName = const Value.absent(),
            Value<String?> contactNo = const Value.absent(),
            Value<String?> cnic = const Value.absent(),
            Value<int?> security = const Value.absent(),
            Value<String?> saleStatus = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<String> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RentalItemsCompanion(
            id: id,
            companyId: companyId,
            createdBy: createdBy,
            name: name,
            price: price,
            remarks: remarks,
            location: location,
            ownerName: ownerName,
            contactNo: contactNo,
            cnic: cnic,
            security: security,
            saleStatus: saleStatus,
            isActive: isActive,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String?> companyId = const Value.absent(),
            Value<String?> createdBy = const Value.absent(),
            required String name,
            Value<int?> price = const Value.absent(),
            Value<String?> remarks = const Value.absent(),
            Value<String?> location = const Value.absent(),
            Value<String?> ownerName = const Value.absent(),
            Value<String?> contactNo = const Value.absent(),
            Value<String?> cnic = const Value.absent(),
            Value<int?> security = const Value.absent(),
            Value<String?> saleStatus = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            required String updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              RentalItemsCompanion.insert(
            id: id,
            companyId: companyId,
            createdBy: createdBy,
            name: name,
            price: price,
            remarks: remarks,
            location: location,
            ownerName: ownerName,
            contactNo: contactNo,
            cnic: cnic,
            security: security,
            saleStatus: saleStatus,
            isActive: isActive,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$RentalItemsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({rentalCommentsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (rentalCommentsRefs) db.rentalComments
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (rentalCommentsRefs)
                    await $_getPrefetchedData<RentalItem, $RentalItemsTable,
                            RentalComment>(
                        currentTable: table,
                        referencedTable: $$RentalItemsTableReferences
                            ._rentalCommentsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$RentalItemsTableReferences(db, table, p0)
                                .rentalCommentsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.parentId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$RentalItemsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $RentalItemsTable,
    RentalItem,
    $$RentalItemsTableFilterComposer,
    $$RentalItemsTableOrderingComposer,
    $$RentalItemsTableAnnotationComposer,
    $$RentalItemsTableCreateCompanionBuilder,
    $$RentalItemsTableUpdateCompanionBuilder,
    (RentalItem, $$RentalItemsTableReferences),
    RentalItem,
    PrefetchHooks Function({bool rentalCommentsRefs})>;
typedef $$RentalCommentsTableCreateCompanionBuilder = RentalCommentsCompanion
    Function({
  required String id,
  required String parentId,
  Value<String?> companyId,
  required String comment,
  required String updatedAt,
  Value<int> rowid,
});
typedef $$RentalCommentsTableUpdateCompanionBuilder = RentalCommentsCompanion
    Function({
  Value<String> id,
  Value<String> parentId,
  Value<String?> companyId,
  Value<String> comment,
  Value<String> updatedAt,
  Value<int> rowid,
});

final class $$RentalCommentsTableReferences
    extends BaseReferences<_$AppDatabase, $RentalCommentsTable, RentalComment> {
  $$RentalCommentsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $RentalItemsTable _parentIdTable(_$AppDatabase db) =>
      db.rentalItems.createAlias(
          $_aliasNameGenerator(db.rentalComments.parentId, db.rentalItems.id));

  $$RentalItemsTableProcessedTableManager get parentId {
    final $_column = $_itemColumn<String>('parent_id')!;

    final manager = $$RentalItemsTableTableManager($_db, $_db.rentalItems)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$RentalCommentsTableFilterComposer
    extends Composer<_$AppDatabase, $RentalCommentsTable> {
  $$RentalCommentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get companyId => $composableBuilder(
      column: $table.companyId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get comment => $composableBuilder(
      column: $table.comment, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  $$RentalItemsTableFilterComposer get parentId {
    final $$RentalItemsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.parentId,
        referencedTable: $db.rentalItems,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RentalItemsTableFilterComposer(
              $db: $db,
              $table: $db.rentalItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$RentalCommentsTableOrderingComposer
    extends Composer<_$AppDatabase, $RentalCommentsTable> {
  $$RentalCommentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get companyId => $composableBuilder(
      column: $table.companyId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get comment => $composableBuilder(
      column: $table.comment, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  $$RentalItemsTableOrderingComposer get parentId {
    final $$RentalItemsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.parentId,
        referencedTable: $db.rentalItems,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RentalItemsTableOrderingComposer(
              $db: $db,
              $table: $db.rentalItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$RentalCommentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RentalCommentsTable> {
  $$RentalCommentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get comment =>
      $composableBuilder(column: $table.comment, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$RentalItemsTableAnnotationComposer get parentId {
    final $$RentalItemsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.parentId,
        referencedTable: $db.rentalItems,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RentalItemsTableAnnotationComposer(
              $db: $db,
              $table: $db.rentalItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$RentalCommentsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RentalCommentsTable,
    RentalComment,
    $$RentalCommentsTableFilterComposer,
    $$RentalCommentsTableOrderingComposer,
    $$RentalCommentsTableAnnotationComposer,
    $$RentalCommentsTableCreateCompanionBuilder,
    $$RentalCommentsTableUpdateCompanionBuilder,
    (RentalComment, $$RentalCommentsTableReferences),
    RentalComment,
    PrefetchHooks Function({bool parentId})> {
  $$RentalCommentsTableTableManager(
      _$AppDatabase db, $RentalCommentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RentalCommentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RentalCommentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RentalCommentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> parentId = const Value.absent(),
            Value<String?> companyId = const Value.absent(),
            Value<String> comment = const Value.absent(),
            Value<String> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RentalCommentsCompanion(
            id: id,
            parentId: parentId,
            companyId: companyId,
            comment: comment,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String parentId,
            Value<String?> companyId = const Value.absent(),
            required String comment,
            required String updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              RentalCommentsCompanion.insert(
            id: id,
            parentId: parentId,
            companyId: companyId,
            comment: comment,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$RentalCommentsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({parentId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (parentId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.parentId,
                    referencedTable:
                        $$RentalCommentsTableReferences._parentIdTable(db),
                    referencedColumn:
                        $$RentalCommentsTableReferences._parentIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$RentalCommentsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $RentalCommentsTable,
    RentalComment,
    $$RentalCommentsTableFilterComposer,
    $$RentalCommentsTableOrderingComposer,
    $$RentalCommentsTableAnnotationComposer,
    $$RentalCommentsTableCreateCompanionBuilder,
    $$RentalCommentsTableUpdateCompanionBuilder,
    (RentalComment, $$RentalCommentsTableReferences),
    RentalComment,
    PrefetchHooks Function({bool parentId})>;
typedef $$WorkingProgressTableCreateCompanionBuilder = WorkingProgressCompanion
    Function({
  required String id,
  Value<String?> companyId,
  required String name,
  Value<String?> status,
  Value<String?> remarks,
  Value<String?> fromUser,
  Value<String?> toUser,
  Value<String?> transferDate,
  Value<String?> nextWorkingDate,
  Value<String?> category,
  Value<bool> isActive,
  required String updatedAt,
  Value<int> rowid,
});
typedef $$WorkingProgressTableUpdateCompanionBuilder = WorkingProgressCompanion
    Function({
  Value<String> id,
  Value<String?> companyId,
  Value<String> name,
  Value<String?> status,
  Value<String?> remarks,
  Value<String?> fromUser,
  Value<String?> toUser,
  Value<String?> transferDate,
  Value<String?> nextWorkingDate,
  Value<String?> category,
  Value<bool> isActive,
  Value<String> updatedAt,
  Value<int> rowid,
});

final class $$WorkingProgressTableReferences extends BaseReferences<
    _$AppDatabase, $WorkingProgressTable, WorkingProgressData> {
  $$WorkingProgressTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$WorkingCommentsTable, List<WorkingComment>>
      _workingCommentsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.workingComments,
              aliasName: $_aliasNameGenerator(
                  db.workingProgress.id, db.workingComments.parentId));

  $$WorkingCommentsTableProcessedTableManager get workingCommentsRefs {
    final manager = $$WorkingCommentsTableTableManager(
            $_db, $_db.workingComments)
        .filter((f) => f.parentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_workingCommentsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$WorkingProgressTableFilterComposer
    extends Composer<_$AppDatabase, $WorkingProgressTable> {
  $$WorkingProgressTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get companyId => $composableBuilder(
      column: $table.companyId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get remarks => $composableBuilder(
      column: $table.remarks, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fromUser => $composableBuilder(
      column: $table.fromUser, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get toUser => $composableBuilder(
      column: $table.toUser, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get transferDate => $composableBuilder(
      column: $table.transferDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get nextWorkingDate => $composableBuilder(
      column: $table.nextWorkingDate,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> workingCommentsRefs(
      Expression<bool> Function($$WorkingCommentsTableFilterComposer f) f) {
    final $$WorkingCommentsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.workingComments,
        getReferencedColumn: (t) => t.parentId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WorkingCommentsTableFilterComposer(
              $db: $db,
              $table: $db.workingComments,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$WorkingProgressTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkingProgressTable> {
  $$WorkingProgressTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get companyId => $composableBuilder(
      column: $table.companyId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get remarks => $composableBuilder(
      column: $table.remarks, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fromUser => $composableBuilder(
      column: $table.fromUser, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get toUser => $composableBuilder(
      column: $table.toUser, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get transferDate => $composableBuilder(
      column: $table.transferDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get nextWorkingDate => $composableBuilder(
      column: $table.nextWorkingDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$WorkingProgressTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkingProgressTable> {
  $$WorkingProgressTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get remarks =>
      $composableBuilder(column: $table.remarks, builder: (column) => column);

  GeneratedColumn<String> get fromUser =>
      $composableBuilder(column: $table.fromUser, builder: (column) => column);

  GeneratedColumn<String> get toUser =>
      $composableBuilder(column: $table.toUser, builder: (column) => column);

  GeneratedColumn<String> get transferDate => $composableBuilder(
      column: $table.transferDate, builder: (column) => column);

  GeneratedColumn<String> get nextWorkingDate => $composableBuilder(
      column: $table.nextWorkingDate, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> workingCommentsRefs<T extends Object>(
      Expression<T> Function($$WorkingCommentsTableAnnotationComposer a) f) {
    final $$WorkingCommentsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.workingComments,
        getReferencedColumn: (t) => t.parentId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WorkingCommentsTableAnnotationComposer(
              $db: $db,
              $table: $db.workingComments,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$WorkingProgressTableTableManager extends RootTableManager<
    _$AppDatabase,
    $WorkingProgressTable,
    WorkingProgressData,
    $$WorkingProgressTableFilterComposer,
    $$WorkingProgressTableOrderingComposer,
    $$WorkingProgressTableAnnotationComposer,
    $$WorkingProgressTableCreateCompanionBuilder,
    $$WorkingProgressTableUpdateCompanionBuilder,
    (WorkingProgressData, $$WorkingProgressTableReferences),
    WorkingProgressData,
    PrefetchHooks Function({bool workingCommentsRefs})> {
  $$WorkingProgressTableTableManager(
      _$AppDatabase db, $WorkingProgressTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkingProgressTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkingProgressTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkingProgressTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String?> companyId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> status = const Value.absent(),
            Value<String?> remarks = const Value.absent(),
            Value<String?> fromUser = const Value.absent(),
            Value<String?> toUser = const Value.absent(),
            Value<String?> transferDate = const Value.absent(),
            Value<String?> nextWorkingDate = const Value.absent(),
            Value<String?> category = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<String> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WorkingProgressCompanion(
            id: id,
            companyId: companyId,
            name: name,
            status: status,
            remarks: remarks,
            fromUser: fromUser,
            toUser: toUser,
            transferDate: transferDate,
            nextWorkingDate: nextWorkingDate,
            category: category,
            isActive: isActive,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String?> companyId = const Value.absent(),
            required String name,
            Value<String?> status = const Value.absent(),
            Value<String?> remarks = const Value.absent(),
            Value<String?> fromUser = const Value.absent(),
            Value<String?> toUser = const Value.absent(),
            Value<String?> transferDate = const Value.absent(),
            Value<String?> nextWorkingDate = const Value.absent(),
            Value<String?> category = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            required String updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              WorkingProgressCompanion.insert(
            id: id,
            companyId: companyId,
            name: name,
            status: status,
            remarks: remarks,
            fromUser: fromUser,
            toUser: toUser,
            transferDate: transferDate,
            nextWorkingDate: nextWorkingDate,
            category: category,
            isActive: isActive,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$WorkingProgressTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({workingCommentsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (workingCommentsRefs) db.workingComments
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (workingCommentsRefs)
                    await $_getPrefetchedData<WorkingProgressData,
                            $WorkingProgressTable, WorkingComment>(
                        currentTable: table,
                        referencedTable: $$WorkingProgressTableReferences
                            ._workingCommentsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$WorkingProgressTableReferences(db, table, p0)
                                .workingCommentsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.parentId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$WorkingProgressTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $WorkingProgressTable,
    WorkingProgressData,
    $$WorkingProgressTableFilterComposer,
    $$WorkingProgressTableOrderingComposer,
    $$WorkingProgressTableAnnotationComposer,
    $$WorkingProgressTableCreateCompanionBuilder,
    $$WorkingProgressTableUpdateCompanionBuilder,
    (WorkingProgressData, $$WorkingProgressTableReferences),
    WorkingProgressData,
    PrefetchHooks Function({bool workingCommentsRefs})>;
typedef $$WorkingCommentsTableCreateCompanionBuilder = WorkingCommentsCompanion
    Function({
  required String id,
  required String parentId,
  Value<String?> companyId,
  required String comment,
  required String updatedAt,
  Value<int> rowid,
});
typedef $$WorkingCommentsTableUpdateCompanionBuilder = WorkingCommentsCompanion
    Function({
  Value<String> id,
  Value<String> parentId,
  Value<String?> companyId,
  Value<String> comment,
  Value<String> updatedAt,
  Value<int> rowid,
});

final class $$WorkingCommentsTableReferences extends BaseReferences<
    _$AppDatabase, $WorkingCommentsTable, WorkingComment> {
  $$WorkingCommentsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $WorkingProgressTable _parentIdTable(_$AppDatabase db) =>
      db.workingProgress.createAlias($_aliasNameGenerator(
          db.workingComments.parentId, db.workingProgress.id));

  $$WorkingProgressTableProcessedTableManager get parentId {
    final $_column = $_itemColumn<String>('parent_id')!;

    final manager =
        $$WorkingProgressTableTableManager($_db, $_db.workingProgress)
            .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$WorkingCommentsTableFilterComposer
    extends Composer<_$AppDatabase, $WorkingCommentsTable> {
  $$WorkingCommentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get companyId => $composableBuilder(
      column: $table.companyId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get comment => $composableBuilder(
      column: $table.comment, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  $$WorkingProgressTableFilterComposer get parentId {
    final $$WorkingProgressTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.parentId,
        referencedTable: $db.workingProgress,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WorkingProgressTableFilterComposer(
              $db: $db,
              $table: $db.workingProgress,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$WorkingCommentsTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkingCommentsTable> {
  $$WorkingCommentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get companyId => $composableBuilder(
      column: $table.companyId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get comment => $composableBuilder(
      column: $table.comment, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  $$WorkingProgressTableOrderingComposer get parentId {
    final $$WorkingProgressTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.parentId,
        referencedTable: $db.workingProgress,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WorkingProgressTableOrderingComposer(
              $db: $db,
              $table: $db.workingProgress,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$WorkingCommentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkingCommentsTable> {
  $$WorkingCommentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get comment =>
      $composableBuilder(column: $table.comment, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$WorkingProgressTableAnnotationComposer get parentId {
    final $$WorkingProgressTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.parentId,
        referencedTable: $db.workingProgress,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WorkingProgressTableAnnotationComposer(
              $db: $db,
              $table: $db.workingProgress,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$WorkingCommentsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $WorkingCommentsTable,
    WorkingComment,
    $$WorkingCommentsTableFilterComposer,
    $$WorkingCommentsTableOrderingComposer,
    $$WorkingCommentsTableAnnotationComposer,
    $$WorkingCommentsTableCreateCompanionBuilder,
    $$WorkingCommentsTableUpdateCompanionBuilder,
    (WorkingComment, $$WorkingCommentsTableReferences),
    WorkingComment,
    PrefetchHooks Function({bool parentId})> {
  $$WorkingCommentsTableTableManager(
      _$AppDatabase db, $WorkingCommentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkingCommentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkingCommentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkingCommentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> parentId = const Value.absent(),
            Value<String?> companyId = const Value.absent(),
            Value<String> comment = const Value.absent(),
            Value<String> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WorkingCommentsCompanion(
            id: id,
            parentId: parentId,
            companyId: companyId,
            comment: comment,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String parentId,
            Value<String?> companyId = const Value.absent(),
            required String comment,
            required String updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              WorkingCommentsCompanion.insert(
            id: id,
            parentId: parentId,
            companyId: companyId,
            comment: comment,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$WorkingCommentsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({parentId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (parentId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.parentId,
                    referencedTable:
                        $$WorkingCommentsTableReferences._parentIdTable(db),
                    referencedColumn:
                        $$WorkingCommentsTableReferences._parentIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$WorkingCommentsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $WorkingCommentsTable,
    WorkingComment,
    $$WorkingCommentsTableFilterComposer,
    $$WorkingCommentsTableOrderingComposer,
    $$WorkingCommentsTableAnnotationComposer,
    $$WorkingCommentsTableCreateCompanionBuilder,
    $$WorkingCommentsTableUpdateCompanionBuilder,
    (WorkingComment, $$WorkingCommentsTableReferences),
    WorkingComment,
    PrefetchHooks Function({bool parentId})>;
typedef $$RemindersTableCreateCompanionBuilder = RemindersCompanion Function({
  Value<int> reminderId,
  required String agentId,
  Value<String?> companyId,
  Value<String?> clientName,
  Value<String?> clientPhone,
  required String reminderTitle,
  Value<String?> reminderDetails,
  required String reminderDate,
  required String reminderTime,
  required String notificationStatus,
  Value<bool> isActive,
  required String createdAt,
  required String updatedAt,
});
typedef $$RemindersTableUpdateCompanionBuilder = RemindersCompanion Function({
  Value<int> reminderId,
  Value<String> agentId,
  Value<String?> companyId,
  Value<String?> clientName,
  Value<String?> clientPhone,
  Value<String> reminderTitle,
  Value<String?> reminderDetails,
  Value<String> reminderDate,
  Value<String> reminderTime,
  Value<String> notificationStatus,
  Value<bool> isActive,
  Value<String> createdAt,
  Value<String> updatedAt,
});

final class $$RemindersTableReferences
    extends BaseReferences<_$AppDatabase, $RemindersTable, Reminder> {
  $$RemindersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $UsersTable _agentIdTable(_$AppDatabase db) => db.users
      .createAlias($_aliasNameGenerator(db.reminders.agentId, db.users.id));

  $$UsersTableProcessedTableManager get agentId {
    final $_column = $_itemColumn<String>('agent_id')!;

    final manager = $$UsersTableTableManager($_db, $_db.users)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_agentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$RemindersTableFilterComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get reminderId => $composableBuilder(
      column: $table.reminderId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get companyId => $composableBuilder(
      column: $table.companyId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get clientName => $composableBuilder(
      column: $table.clientName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get clientPhone => $composableBuilder(
      column: $table.clientPhone, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reminderTitle => $composableBuilder(
      column: $table.reminderTitle, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reminderDetails => $composableBuilder(
      column: $table.reminderDetails,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reminderDate => $composableBuilder(
      column: $table.reminderDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reminderTime => $composableBuilder(
      column: $table.reminderTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notificationStatus => $composableBuilder(
      column: $table.notificationStatus,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  $$UsersTableFilterComposer get agentId {
    final $$UsersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.agentId,
        referencedTable: $db.users,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$UsersTableFilterComposer(
              $db: $db,
              $table: $db.users,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$RemindersTableOrderingComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get reminderId => $composableBuilder(
      column: $table.reminderId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get companyId => $composableBuilder(
      column: $table.companyId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get clientName => $composableBuilder(
      column: $table.clientName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get clientPhone => $composableBuilder(
      column: $table.clientPhone, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reminderTitle => $composableBuilder(
      column: $table.reminderTitle,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reminderDetails => $composableBuilder(
      column: $table.reminderDetails,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reminderDate => $composableBuilder(
      column: $table.reminderDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reminderTime => $composableBuilder(
      column: $table.reminderTime,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notificationStatus => $composableBuilder(
      column: $table.notificationStatus,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  $$UsersTableOrderingComposer get agentId {
    final $$UsersTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.agentId,
        referencedTable: $db.users,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$UsersTableOrderingComposer(
              $db: $db,
              $table: $db.users,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$RemindersTableAnnotationComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get reminderId => $composableBuilder(
      column: $table.reminderId, builder: (column) => column);

  GeneratedColumn<String> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get clientName => $composableBuilder(
      column: $table.clientName, builder: (column) => column);

  GeneratedColumn<String> get clientPhone => $composableBuilder(
      column: $table.clientPhone, builder: (column) => column);

  GeneratedColumn<String> get reminderTitle => $composableBuilder(
      column: $table.reminderTitle, builder: (column) => column);

  GeneratedColumn<String> get reminderDetails => $composableBuilder(
      column: $table.reminderDetails, builder: (column) => column);

  GeneratedColumn<String> get reminderDate => $composableBuilder(
      column: $table.reminderDate, builder: (column) => column);

  GeneratedColumn<String> get reminderTime => $composableBuilder(
      column: $table.reminderTime, builder: (column) => column);

  GeneratedColumn<String> get notificationStatus => $composableBuilder(
      column: $table.notificationStatus, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$UsersTableAnnotationComposer get agentId {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.agentId,
        referencedTable: $db.users,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$UsersTableAnnotationComposer(
              $db: $db,
              $table: $db.users,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$RemindersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RemindersTable,
    Reminder,
    $$RemindersTableFilterComposer,
    $$RemindersTableOrderingComposer,
    $$RemindersTableAnnotationComposer,
    $$RemindersTableCreateCompanionBuilder,
    $$RemindersTableUpdateCompanionBuilder,
    (Reminder, $$RemindersTableReferences),
    Reminder,
    PrefetchHooks Function({bool agentId})> {
  $$RemindersTableTableManager(_$AppDatabase db, $RemindersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RemindersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RemindersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RemindersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> reminderId = const Value.absent(),
            Value<String> agentId = const Value.absent(),
            Value<String?> companyId = const Value.absent(),
            Value<String?> clientName = const Value.absent(),
            Value<String?> clientPhone = const Value.absent(),
            Value<String> reminderTitle = const Value.absent(),
            Value<String?> reminderDetails = const Value.absent(),
            Value<String> reminderDate = const Value.absent(),
            Value<String> reminderTime = const Value.absent(),
            Value<String> notificationStatus = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<String> createdAt = const Value.absent(),
            Value<String> updatedAt = const Value.absent(),
          }) =>
              RemindersCompanion(
            reminderId: reminderId,
            agentId: agentId,
            companyId: companyId,
            clientName: clientName,
            clientPhone: clientPhone,
            reminderTitle: reminderTitle,
            reminderDetails: reminderDetails,
            reminderDate: reminderDate,
            reminderTime: reminderTime,
            notificationStatus: notificationStatus,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> reminderId = const Value.absent(),
            required String agentId,
            Value<String?> companyId = const Value.absent(),
            Value<String?> clientName = const Value.absent(),
            Value<String?> clientPhone = const Value.absent(),
            required String reminderTitle,
            Value<String?> reminderDetails = const Value.absent(),
            required String reminderDate,
            required String reminderTime,
            required String notificationStatus,
            Value<bool> isActive = const Value.absent(),
            required String createdAt,
            required String updatedAt,
          }) =>
              RemindersCompanion.insert(
            reminderId: reminderId,
            agentId: agentId,
            companyId: companyId,
            clientName: clientName,
            clientPhone: clientPhone,
            reminderTitle: reminderTitle,
            reminderDetails: reminderDetails,
            reminderDate: reminderDate,
            reminderTime: reminderTime,
            notificationStatus: notificationStatus,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$RemindersTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({agentId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (agentId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.agentId,
                    referencedTable:
                        $$RemindersTableReferences._agentIdTable(db),
                    referencedColumn:
                        $$RemindersTableReferences._agentIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$RemindersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $RemindersTable,
    Reminder,
    $$RemindersTableFilterComposer,
    $$RemindersTableOrderingComposer,
    $$RemindersTableAnnotationComposer,
    $$RemindersTableCreateCompanionBuilder,
    $$RemindersTableUpdateCompanionBuilder,
    (Reminder, $$RemindersTableReferences),
    Reminder,
    PrefetchHooks Function({bool agentId})>;
typedef $$ReportsTableCreateCompanionBuilder = ReportsCompanion Function({
  required String id,
  Value<String?> companyId,
  required String name,
  Value<String?> password,
  Value<String?> filePath,
  required String updatedAt,
  Value<int> rowid,
});
typedef $$ReportsTableUpdateCompanionBuilder = ReportsCompanion Function({
  Value<String> id,
  Value<String?> companyId,
  Value<String> name,
  Value<String?> password,
  Value<String?> filePath,
  Value<String> updatedAt,
  Value<int> rowid,
});

class $$ReportsTableFilterComposer
    extends Composer<_$AppDatabase, $ReportsTable> {
  $$ReportsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get companyId => $composableBuilder(
      column: $table.companyId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get password => $composableBuilder(
      column: $table.password, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$ReportsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReportsTable> {
  $$ReportsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get companyId => $composableBuilder(
      column: $table.companyId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get password => $composableBuilder(
      column: $table.password, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$ReportsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReportsTable> {
  $$ReportsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get password =>
      $composableBuilder(column: $table.password, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ReportsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ReportsTable,
    Report,
    $$ReportsTableFilterComposer,
    $$ReportsTableOrderingComposer,
    $$ReportsTableAnnotationComposer,
    $$ReportsTableCreateCompanionBuilder,
    $$ReportsTableUpdateCompanionBuilder,
    (Report, BaseReferences<_$AppDatabase, $ReportsTable, Report>),
    Report,
    PrefetchHooks Function()> {
  $$ReportsTableTableManager(_$AppDatabase db, $ReportsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReportsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReportsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReportsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String?> companyId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> password = const Value.absent(),
            Value<String?> filePath = const Value.absent(),
            Value<String> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ReportsCompanion(
            id: id,
            companyId: companyId,
            name: name,
            password: password,
            filePath: filePath,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String?> companyId = const Value.absent(),
            required String name,
            Value<String?> password = const Value.absent(),
            Value<String?> filePath = const Value.absent(),
            required String updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              ReportsCompanion.insert(
            id: id,
            companyId: companyId,
            name: name,
            password: password,
            filePath: filePath,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ReportsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ReportsTable,
    Report,
    $$ReportsTableFilterComposer,
    $$ReportsTableOrderingComposer,
    $$ReportsTableAnnotationComposer,
    $$ReportsTableCreateCompanionBuilder,
    $$ReportsTableUpdateCompanionBuilder,
    (Report, BaseReferences<_$AppDatabase, $ReportsTable, Report>),
    Report,
    PrefetchHooks Function()>;
typedef $$DeletionsTableCreateCompanionBuilder = DeletionsCompanion Function({
  Value<int> id,
  required String module,
  required String entityId,
  Value<String?> companyId,
  required String updatedAt,
});
typedef $$DeletionsTableUpdateCompanionBuilder = DeletionsCompanion Function({
  Value<int> id,
  Value<String> module,
  Value<String> entityId,
  Value<String?> companyId,
  Value<String> updatedAt,
});

class $$DeletionsTableFilterComposer
    extends Composer<_$AppDatabase, $DeletionsTable> {
  $$DeletionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get module => $composableBuilder(
      column: $table.module, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get companyId => $composableBuilder(
      column: $table.companyId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$DeletionsTableOrderingComposer
    extends Composer<_$AppDatabase, $DeletionsTable> {
  $$DeletionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get module => $composableBuilder(
      column: $table.module, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get companyId => $composableBuilder(
      column: $table.companyId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$DeletionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DeletionsTable> {
  $$DeletionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get module =>
      $composableBuilder(column: $table.module, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DeletionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DeletionsTable,
    Deletion,
    $$DeletionsTableFilterComposer,
    $$DeletionsTableOrderingComposer,
    $$DeletionsTableAnnotationComposer,
    $$DeletionsTableCreateCompanionBuilder,
    $$DeletionsTableUpdateCompanionBuilder,
    (Deletion, BaseReferences<_$AppDatabase, $DeletionsTable, Deletion>),
    Deletion,
    PrefetchHooks Function()> {
  $$DeletionsTableTableManager(_$AppDatabase db, $DeletionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeletionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeletionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeletionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> module = const Value.absent(),
            Value<String> entityId = const Value.absent(),
            Value<String?> companyId = const Value.absent(),
            Value<String> updatedAt = const Value.absent(),
          }) =>
              DeletionsCompanion(
            id: id,
            module: module,
            entityId: entityId,
            companyId: companyId,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String module,
            required String entityId,
            Value<String?> companyId = const Value.absent(),
            required String updatedAt,
          }) =>
              DeletionsCompanion.insert(
            id: id,
            module: module,
            entityId: entityId,
            companyId: companyId,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DeletionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DeletionsTable,
    Deletion,
    $$DeletionsTableFilterComposer,
    $$DeletionsTableOrderingComposer,
    $$DeletionsTableAnnotationComposer,
    $$DeletionsTableCreateCompanionBuilder,
    $$DeletionsTableUpdateCompanionBuilder,
    (Deletion, BaseReferences<_$AppDatabase, $DeletionsTable, Deletion>),
    Deletion,
    PrefetchHooks Function()>;
typedef $$SyncLogsTableCreateCompanionBuilder = SyncLogsCompanion Function({
  Value<int> id,
  required String direction,
  Value<String?> module,
  Value<String?> exportId,
  Value<String?> fileName,
  required String status,
  Value<String?> error,
  Value<String?> companyId,
  required String startedAt,
  Value<String?> finishedAt,
});
typedef $$SyncLogsTableUpdateCompanionBuilder = SyncLogsCompanion Function({
  Value<int> id,
  Value<String> direction,
  Value<String?> module,
  Value<String?> exportId,
  Value<String?> fileName,
  Value<String> status,
  Value<String?> error,
  Value<String?> companyId,
  Value<String> startedAt,
  Value<String?> finishedAt,
});

class $$SyncLogsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncLogsTable> {
  $$SyncLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get direction => $composableBuilder(
      column: $table.direction, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get module => $composableBuilder(
      column: $table.module, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get exportId => $composableBuilder(
      column: $table.exportId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fileName => $composableBuilder(
      column: $table.fileName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get error => $composableBuilder(
      column: $table.error, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get companyId => $composableBuilder(
      column: $table.companyId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get finishedAt => $composableBuilder(
      column: $table.finishedAt, builder: (column) => ColumnFilters(column));
}

class $$SyncLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncLogsTable> {
  $$SyncLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get direction => $composableBuilder(
      column: $table.direction, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get module => $composableBuilder(
      column: $table.module, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get exportId => $composableBuilder(
      column: $table.exportId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fileName => $composableBuilder(
      column: $table.fileName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get error => $composableBuilder(
      column: $table.error, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get companyId => $composableBuilder(
      column: $table.companyId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get finishedAt => $composableBuilder(
      column: $table.finishedAt, builder: (column) => ColumnOrderings(column));
}

class $$SyncLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncLogsTable> {
  $$SyncLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<String> get module =>
      $composableBuilder(column: $table.module, builder: (column) => column);

  GeneratedColumn<String> get exportId =>
      $composableBuilder(column: $table.exportId, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<String> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<String> get finishedAt => $composableBuilder(
      column: $table.finishedAt, builder: (column) => column);
}

class $$SyncLogsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncLogsTable,
    SyncLog,
    $$SyncLogsTableFilterComposer,
    $$SyncLogsTableOrderingComposer,
    $$SyncLogsTableAnnotationComposer,
    $$SyncLogsTableCreateCompanionBuilder,
    $$SyncLogsTableUpdateCompanionBuilder,
    (SyncLog, BaseReferences<_$AppDatabase, $SyncLogsTable, SyncLog>),
    SyncLog,
    PrefetchHooks Function()> {
  $$SyncLogsTableTableManager(_$AppDatabase db, $SyncLogsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> direction = const Value.absent(),
            Value<String?> module = const Value.absent(),
            Value<String?> exportId = const Value.absent(),
            Value<String?> fileName = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> error = const Value.absent(),
            Value<String?> companyId = const Value.absent(),
            Value<String> startedAt = const Value.absent(),
            Value<String?> finishedAt = const Value.absent(),
          }) =>
              SyncLogsCompanion(
            id: id,
            direction: direction,
            module: module,
            exportId: exportId,
            fileName: fileName,
            status: status,
            error: error,
            companyId: companyId,
            startedAt: startedAt,
            finishedAt: finishedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String direction,
            Value<String?> module = const Value.absent(),
            Value<String?> exportId = const Value.absent(),
            Value<String?> fileName = const Value.absent(),
            required String status,
            Value<String?> error = const Value.absent(),
            Value<String?> companyId = const Value.absent(),
            required String startedAt,
            Value<String?> finishedAt = const Value.absent(),
          }) =>
              SyncLogsCompanion.insert(
            id: id,
            direction: direction,
            module: module,
            exportId: exportId,
            fileName: fileName,
            status: status,
            error: error,
            companyId: companyId,
            startedAt: startedAt,
            finishedAt: finishedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncLogsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncLogsTable,
    SyncLog,
    $$SyncLogsTableFilterComposer,
    $$SyncLogsTableOrderingComposer,
    $$SyncLogsTableAnnotationComposer,
    $$SyncLogsTableCreateCompanionBuilder,
    $$SyncLogsTableUpdateCompanionBuilder,
    (SyncLog, BaseReferences<_$AppDatabase, $SyncLogsTable, SyncLog>),
    SyncLog,
    PrefetchHooks Function()>;
typedef $$ClientsTableCreateCompanionBuilder = ClientsCompanion Function({
  required String id,
  Value<String?> companyId,
  Value<String?> createdBy,
  required String clientName,
  Value<String?> clientContact,
  Value<String?> address,
  Value<String?> city,
  Value<String?> organization,
  Value<String?> plot,
  Value<String?> size,
  Value<String?> location,
  Value<int?> budget,
  Value<String?> remarks,
  Value<String?> date,
  Value<String?> source,
  required String updatedAt,
  Value<int> rowid,
});
typedef $$ClientsTableUpdateCompanionBuilder = ClientsCompanion Function({
  Value<String> id,
  Value<String?> companyId,
  Value<String?> createdBy,
  Value<String> clientName,
  Value<String?> clientContact,
  Value<String?> address,
  Value<String?> city,
  Value<String?> organization,
  Value<String?> plot,
  Value<String?> size,
  Value<String?> location,
  Value<int?> budget,
  Value<String?> remarks,
  Value<String?> date,
  Value<String?> source,
  Value<String> updatedAt,
  Value<int> rowid,
});

class $$ClientsTableFilterComposer
    extends Composer<_$AppDatabase, $ClientsTable> {
  $$ClientsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get companyId => $composableBuilder(
      column: $table.companyId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdBy => $composableBuilder(
      column: $table.createdBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get clientName => $composableBuilder(
      column: $table.clientName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get clientContact => $composableBuilder(
      column: $table.clientContact, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get address => $composableBuilder(
      column: $table.address, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get city => $composableBuilder(
      column: $table.city, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get organization => $composableBuilder(
      column: $table.organization, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get plot => $composableBuilder(
      column: $table.plot, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get size => $composableBuilder(
      column: $table.size, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get location => $composableBuilder(
      column: $table.location, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get budget => $composableBuilder(
      column: $table.budget, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get remarks => $composableBuilder(
      column: $table.remarks, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$ClientsTableOrderingComposer
    extends Composer<_$AppDatabase, $ClientsTable> {
  $$ClientsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get companyId => $composableBuilder(
      column: $table.companyId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdBy => $composableBuilder(
      column: $table.createdBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get clientName => $composableBuilder(
      column: $table.clientName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get clientContact => $composableBuilder(
      column: $table.clientContact,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get address => $composableBuilder(
      column: $table.address, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get city => $composableBuilder(
      column: $table.city, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get organization => $composableBuilder(
      column: $table.organization,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get plot => $composableBuilder(
      column: $table.plot, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get size => $composableBuilder(
      column: $table.size, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get location => $composableBuilder(
      column: $table.location, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get budget => $composableBuilder(
      column: $table.budget, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get remarks => $composableBuilder(
      column: $table.remarks, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$ClientsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClientsTable> {
  $$ClientsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get clientName => $composableBuilder(
      column: $table.clientName, builder: (column) => column);

  GeneratedColumn<String> get clientContact => $composableBuilder(
      column: $table.clientContact, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get city =>
      $composableBuilder(column: $table.city, builder: (column) => column);

  GeneratedColumn<String> get organization => $composableBuilder(
      column: $table.organization, builder: (column) => column);

  GeneratedColumn<String> get plot =>
      $composableBuilder(column: $table.plot, builder: (column) => column);

  GeneratedColumn<String> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<int> get budget =>
      $composableBuilder(column: $table.budget, builder: (column) => column);

  GeneratedColumn<String> get remarks =>
      $composableBuilder(column: $table.remarks, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ClientsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ClientsTable,
    Client,
    $$ClientsTableFilterComposer,
    $$ClientsTableOrderingComposer,
    $$ClientsTableAnnotationComposer,
    $$ClientsTableCreateCompanionBuilder,
    $$ClientsTableUpdateCompanionBuilder,
    (Client, BaseReferences<_$AppDatabase, $ClientsTable, Client>),
    Client,
    PrefetchHooks Function()> {
  $$ClientsTableTableManager(_$AppDatabase db, $ClientsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClientsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClientsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClientsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String?> companyId = const Value.absent(),
            Value<String?> createdBy = const Value.absent(),
            Value<String> clientName = const Value.absent(),
            Value<String?> clientContact = const Value.absent(),
            Value<String?> address = const Value.absent(),
            Value<String?> city = const Value.absent(),
            Value<String?> organization = const Value.absent(),
            Value<String?> plot = const Value.absent(),
            Value<String?> size = const Value.absent(),
            Value<String?> location = const Value.absent(),
            Value<int?> budget = const Value.absent(),
            Value<String?> remarks = const Value.absent(),
            Value<String?> date = const Value.absent(),
            Value<String?> source = const Value.absent(),
            Value<String> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ClientsCompanion(
            id: id,
            companyId: companyId,
            createdBy: createdBy,
            clientName: clientName,
            clientContact: clientContact,
            address: address,
            city: city,
            organization: organization,
            plot: plot,
            size: size,
            location: location,
            budget: budget,
            remarks: remarks,
            date: date,
            source: source,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String?> companyId = const Value.absent(),
            Value<String?> createdBy = const Value.absent(),
            required String clientName,
            Value<String?> clientContact = const Value.absent(),
            Value<String?> address = const Value.absent(),
            Value<String?> city = const Value.absent(),
            Value<String?> organization = const Value.absent(),
            Value<String?> plot = const Value.absent(),
            Value<String?> size = const Value.absent(),
            Value<String?> location = const Value.absent(),
            Value<int?> budget = const Value.absent(),
            Value<String?> remarks = const Value.absent(),
            Value<String?> date = const Value.absent(),
            Value<String?> source = const Value.absent(),
            required String updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              ClientsCompanion.insert(
            id: id,
            companyId: companyId,
            createdBy: createdBy,
            clientName: clientName,
            clientContact: clientContact,
            address: address,
            city: city,
            organization: organization,
            plot: plot,
            size: size,
            location: location,
            budget: budget,
            remarks: remarks,
            date: date,
            source: source,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ClientsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ClientsTable,
    Client,
    $$ClientsTableFilterComposer,
    $$ClientsTableOrderingComposer,
    $$ClientsTableAnnotationComposer,
    $$ClientsTableCreateCompanionBuilder,
    $$ClientsTableUpdateCompanionBuilder,
    (Client, BaseReferences<_$AppDatabase, $ClientsTable, Client>),
    Client,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CompaniesTableTableManager get companies =>
      $$CompaniesTableTableManager(_db, _db.companies);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db, _db.users);
  $$SocietiesTableTableManager get societies =>
      $$SocietiesTableTableManager(_db, _db.societies);
  $$BlocksTableTableManager get blocks =>
      $$BlocksTableTableManager(_db, _db.blocks);
  $$PropertiesTableTableManager get properties =>
      $$PropertiesTableTableManager(_db, _db.properties);
  $$PropertyCommentsTableTableManager get propertyComments =>
      $$PropertyCommentsTableTableManager(_db, _db.propertyComments);
  $$FilesTableTableTableManager get filesTable =>
      $$FilesTableTableTableManager(_db, _db.filesTable);
  $$FileCommentsTableTableManager get fileComments =>
      $$FileCommentsTableTableManager(_db, _db.fileComments);
  $$RentalItemsTableTableManager get rentalItems =>
      $$RentalItemsTableTableManager(_db, _db.rentalItems);
  $$RentalCommentsTableTableManager get rentalComments =>
      $$RentalCommentsTableTableManager(_db, _db.rentalComments);
  $$WorkingProgressTableTableManager get workingProgress =>
      $$WorkingProgressTableTableManager(_db, _db.workingProgress);
  $$WorkingCommentsTableTableManager get workingComments =>
      $$WorkingCommentsTableTableManager(_db, _db.workingComments);
  $$RemindersTableTableManager get reminders =>
      $$RemindersTableTableManager(_db, _db.reminders);
  $$ReportsTableTableManager get reports =>
      $$ReportsTableTableManager(_db, _db.reports);
  $$DeletionsTableTableManager get deletions =>
      $$DeletionsTableTableManager(_db, _db.deletions);
  $$SyncLogsTableTableManager get syncLogs =>
      $$SyncLogsTableTableManager(_db, _db.syncLogs);
  $$ClientsTableTableManager get clients =>
      $$ClientsTableTableManager(_db, _db.clients);
}
