import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'firebase_config.dart';
import 'package:shared/shared.dart' show AppDatabase;
import 'package:drift/drift.dart' as d; 

class RestSyncManager {
  static final RestSyncManager instance = RestSyncManager._();
  RestSyncManager._();
  
  bool _isSyncing = false;
  
  Future<Map<String, dynamic>> syncAllData() async {
    if (_isSyncing) {
      debugPrint('⏸️ RestSyncManager: Sync already in progress');
      return {'success': false, 'message': 'Sync already in progress'};
    }
    
    _isSyncing = true;
    debugPrint('🔄 RestSyncManager: Starting REST API sync...');
    
    try {
      final usersResult = await syncUsers();
      final companiesResult = await syncCompanies();
      final tradingResult = await syncTradingEntries();
      final workingResult = await syncWorkingProgress();
      final expenditureResult = await syncExpenditures();
      final inventoryResult = await syncInventoryFiles();
      //final rentalResult = await syncRentalItems();
      final todoResult = await syncReminders();

      debugPrint('⏸️ RestSyncManager: Rental items sync temporarily disabled');

      
      debugPrint('✅ RestSyncManager: All data synced successfully');
      
      return {
        'success': true,
        'message': 'Data synced successfully',
        'users': usersResult['count'] ?? 0,
        'companies': companiesResult['count'] ?? 0,
        'trading': tradingResult['count'] ?? 0,
        'working': workingResult['count'] ?? 0,
        'expenditure': expenditureResult['count'] ?? 0,
        'inventory': inventoryResult['count'] ?? 0,
        'rental': 0,
        'todo': todoResult['count'] ?? 0,
      };
    } catch (e) {
      debugPrint('❌ RestSyncManager: Sync failed: $e');
      return {'success': false, 'message': 'Sync failed: $e'};
    } finally {
      _isSyncing = false;
    }
  }
  
  Future<Map<String, dynamic>> syncUsers() async {
    try {
      debugPrint('📥 RestSyncManager: Fetching users from Firestore...');
      
      final url = '${FirebaseConfig.firestoreBaseUrl}/users?key=${FirebaseConfig.apiKey}';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final documents = data['documents'] as List? ?? [];
        
        debugPrint('📥 RestSyncManager: Fetched ${documents.length} users');
        
        await _saveUsersToLocal(documents);
        debugPrint('✅ RestSyncManager: Users saved to local DB');
        
        return {'success': true, 'count': documents.length};
      } else {
        debugPrint('❌ RestSyncManager: Failed to fetch users: ${response.statusCode}');
        return {'success': false, 'count': 0, 'error': response.body};
      }
    } catch (e) {
      debugPrint('❌ RestSyncManager: Error syncing users: $e');
      return {'success': false, 'count': 0, 'error': e.toString()};
    }
  }
  
  Future<Map<String, dynamic>> syncCompanies() async {
    try {
      debugPrint('📥 RestSyncManager: Fetching companies from Firestore...');
      
      final url = '${FirebaseConfig.firestoreBaseUrl}/companies?key=${FirebaseConfig.apiKey}';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final documents = data['documents'] as List? ?? [];
        
        debugPrint('📥 RestSyncManager: Fetched ${documents.length} companies');
        
        await _saveCompaniesToLocal(documents);
        debugPrint('✅ RestSyncManager: Companies saved to local DB');
        
        return {'success': true, 'count': documents.length};
      } else {
        debugPrint('❌ RestSyncManager: Failed to fetch companies: ${response.statusCode}');
        return {'success': false, 'count': 0, 'error': response.body};
      }
    } catch (e) {
      debugPrint('❌ RestSyncManager: Error syncing companies: $e');
      return {'success': false, 'count': 0, 'error': e.toString()};
    }
  }
  
 Future<void> _saveUsersToLocal(List documents) async {
  final db = await AppDatabase.instance();
  
  for (final doc in documents) {
    final docName = doc['name'] as String;
    final docId = docName.split('/').last;
    final fields = doc['fields'] as Map<String, dynamic>;
    
    try {
      final email = _extractString(fields['email']) ?? '';
      final name = _extractString(fields['name']) ?? '';
      final passwordHash = _extractString(fields['password_hash']);
      final salt = _extractString(fields['salt']);
      final iterations = _extractInt(fields['iterations']) ?? 10000;
      
      // ✅ CRITICAL: Check if password hash is valid
      String finalPasswordHash;
      String finalSalt;
      bool needsPasswordReset = false;
      
      if (passwordHash != null && passwordHash.isNotEmpty && 
          salt != null && salt.isNotEmpty &&
          !passwordHash.contains('nullValue')) {
        // ✅ Valid password hash - use it
        finalPasswordHash = passwordHash;
        finalSalt = salt;
        debugPrint('✅ RestSyncManager: User $email has valid password');
      } else {
        // ❌ Invalid password hash - assign temporary password
        // Temporary password: "Temp@123" (user ko batayen)
        finalSalt = DateTime.now().millisecondsSinceEpoch.toString();
        final tempPassword = 'Temp@123';
        
        // Hash the temporary password
        finalPasswordHash = _hashTempPassword(tempPassword, finalSalt, iterations);
        needsPasswordReset = true;
        
        debugPrint('⚠️ RestSyncManager: User $email assigned temporary password (Temp@123)');
      }
      
      // ✅ Check if user already exists
      final existingUser = await db.customSelect(
        'SELECT id FROM users WHERE id = ? OR email = ?',
        variables: [
          d.Variable.withString(docId),
          d.Variable.withString(email),
        ],
      ).getSingleOrNull();
      
      if (existingUser != null) {
        debugPrint('⚠️ RestSyncManager: User $email already exists, skipping');
        continue;
      }
      
      // ✅ Save user to local DB
      await db.customStatement(
        '''INSERT INTO users (
          id, username, password_hash, salt, iterations, user_id, name, email, 
          contact_no, role, permissions, company_id, status, is_first_login, 
          is_active, profile_picture_path, created_at, updated_at, is_synced
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          docId,
          _extractString(fields['username']) ?? email.split('@').first,
          finalPasswordHash,
          finalSalt,
          iterations,
          _extractString(fields['user_id']) ?? docId,
          name,
          email,
          _extractString(fields['contact_no']),
          _extractString(fields['role']) ?? 'agent',
          _extractString(fields['permissions']) ?? '{}',
          _extractString(fields['company_id']) ?? '',
          _extractString(fields['status']) ?? 'active',
          needsPasswordReset ? 1 : 0,  // ✅ Force password reset if temp password
          _extractInt(fields['is_active']) ?? 1,
          _extractString(fields['profile_picture_path']) ?? '',
          _extractString(fields['created_at']) ?? DateTime.now().toIso8601String(),
          _extractString(fields['updated_at']) ?? DateTime.now().toIso8601String(),
          1,
        ],
      );
      
      debugPrint('✅ RestSyncManager: User $email saved successfully');
    } catch (e) {
      debugPrint('❌ RestSyncManager: Error saving user: $e');
    }
  }
}

// ✅ 1. Trading Entries Sync
Future<Map<String, dynamic>> syncTradingEntries() async {
  try {
    debugPrint('📥 RestSyncManager: Fetching trading entries...');
    final url = '${FirebaseConfig.firestoreBaseUrl}/trading_entries?key=${FirebaseConfig.apiKey}';
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final documents = data['documents'] as List? ?? [];
      debugPrint('📥 RestSyncManager: Fetched ${documents.length} trading entries');
      await _saveTradingEntriesToLocal(documents);
      return {'success': true, 'count': documents.length};
    }
    return {'success': false, 'count': 0};
  } catch (e) {
    debugPrint('❌ RestSyncManager: Error syncing trading: $e');
    return {'success': false, 'count': 0};
  }
}

// ✅ 2. Working Progress (Agent Working) Sync
Future<Map<String, dynamic>> syncWorkingProgress() async {
  try {
    debugPrint('📥 RestSyncManager: Fetching working progress...');
    final url = '${FirebaseConfig.firestoreBaseUrl}/working_progress?key=${FirebaseConfig.apiKey}';
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final documents = data['documents'] as List? ?? [];
      debugPrint('📥 RestSyncManager: Fetched ${documents.length} working progress entries');
      await _saveWorkingProgressToLocal(documents);
      return {'success': true, 'count': documents.length};
    }
    return {'success': false, 'count': 0};
  } catch (e) {
    debugPrint('❌ RestSyncManager: Error syncing working progress: $e');
    return {'success': false, 'count': 0};
  }
}

// ✅ 3. Expenditures Sync
Future<Map<String, dynamic>> syncExpenditures() async {
  try {
    debugPrint('📥 RestSyncManager: Fetching expenditures...');
    final url = '${FirebaseConfig.firestoreBaseUrl}/expenditures?key=${FirebaseConfig.apiKey}';
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final documents = data['documents'] as List? ?? [];
      debugPrint('📥 RestSyncManager: Fetched ${documents.length} expenditures');
      await _saveExpendituresToLocal(documents);
      return {'success': true, 'count': documents.length};
    }
    return {'success': false, 'count': 0};
  } catch (e) {
    debugPrint('❌ RestSyncManager: Error syncing expenditures: $e');
    return {'success': false, 'count': 0};
  }
}

// ✅ 4. Inventory Files Sync
Future<Map<String, dynamic>> syncInventoryFiles() async {
  try {
    debugPrint('📥 RestSyncManager: Fetching inventory files...');
    final url = '${FirebaseConfig.firestoreBaseUrl}/files_table?key=${FirebaseConfig.apiKey}';
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final documents = data['documents'] as List? ?? [];
      debugPrint('📥 RestSyncManager: Fetched ${documents.length} inventory files');
      await _saveInventoryFilesToLocal(documents);
      return {'success': true, 'count': documents.length};
    }
    return {'success': false, 'count': 0};
  } catch (e) {
    debugPrint('❌ RestSyncManager: Error syncing inventory: $e');
    return {'success': false, 'count': 0};
  }
}

// ✅ 5. Rental Items Sync
Future<Map<String, dynamic>> syncRentalItems() async {
  try {
    debugPrint('📥 RestSyncManager: Fetching rental items...');
    final url = '${FirebaseConfig.firestoreBaseUrl}/rental_items?key=${FirebaseConfig.apiKey}';
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final documents = data['documents'] as List? ?? [];
      debugPrint('📥 RestSyncManager: Fetched ${documents.length} rental items');
      await _saveRentalItemsToLocal(documents);
      return {'success': true, 'count': documents.length};
    }
    return {'success': false, 'count': 0};
  } catch (e) {
    debugPrint('❌ RestSyncManager: Error syncing rental: $e');
    return {'success': false, 'count': 0};
  }
}

// ✅ 6. Reminders (Todo) Sync
Future<Map<String, dynamic>> syncReminders() async {
  try {
    debugPrint('📥 RestSyncManager: Fetching reminders...');
    final url = '${FirebaseConfig.firestoreBaseUrl}/reminders?key=${FirebaseConfig.apiKey}';
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final documents = data['documents'] as List? ?? [];
      debugPrint('📥 RestSyncManager: Fetched ${documents.length} reminders');
      await _saveRemindersToLocal(documents);
      return {'success': true, 'count': documents.length};
    }
    return {'success': false, 'count': 0};
  } catch (e) {
    debugPrint('❌ RestSyncManager: Error syncing reminders: $e');
    return {'success': false, 'count': 0};
  }
}

// ✅ Helper: Hash temporary password
String _hashTempPassword(String password, String salt, int iterations) {
  // Simple hash - use your existing PasswordHashingService
  try {
    // Format: iterations:salt:hash
    return '$iterations:$salt:${_simpleHash(password + salt)}';
  } catch (e) {
    debugPrint('Error hashing temp password: $e');
    return '';
  }
}

String _simpleHash(String input) {
  // Simple hash function - replace with your actual hashing logic
  int hash = 0;
  for (int i = 0; i < input.length; i++) {
    hash = (hash * 31 + input.codeUnitAt(i)) & 0x7fffffff;
  }
  return hash.toRadixString(16);
}

  Future<void> _saveCompaniesToLocal(List documents) async {
    final db = await AppDatabase.instance();
    
    for (final doc in documents) {
      final docName = doc['name'] as String;
      final docId = docName.split('/').last;
      final fields = doc['fields'] as Map<String, dynamic>;
      
      try {
        await db.customStatement(
          '''INSERT OR REPLACE INTO companies (
            id, name, status, metadata, max_user_limit, subscription_tier, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            docId,
            _extractString(fields['name']) ?? '',
            _extractString(fields['status']) ?? 'active',
            _extractString(fields['metadata']) ?? '{}',
            _extractInt(fields['max_user_limit']) ?? 5,
            _extractString(fields['subscription_tier']) ?? 'Starter',
            _extractString(fields['created_at']) ?? DateTime.now().toIso8601String(),
            _extractString(fields['updated_at']) ?? DateTime.now().toIso8601String(),
          ],
        );
      } catch (e) {
        debugPrint('❌ RestSyncManager: Error saving company $docId: $e');
      }
    }
  }
  // ✅ Save Trading Entries
Future<void> _saveTradingEntriesToLocal(List documents) async {
  final db = await AppDatabase.instance();
  for (final doc in documents) {
    final docName = doc['name'] as String;
    final docId = docName.split('/').last;
    final fields = doc['fields'] as Map<String, dynamic>;
    
    try {
      await db.customStatement(
        '''INSERT OR REPLACE INTO trading_entries (
          id, entry_type, date, person_name, mobile_no, estate_name, 
          quantity, unit_price, image_path, company_id, is_active, 
          is_synced, created_at, updated_at, status
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          docId,
          _extractString(fields['entry_type']) ?? '',
          _extractString(fields['date']) ?? DateTime.now().toIso8601String(),
          _extractString(fields['person_name']) ?? '',
          _extractString(fields['mobile_no']) ?? '',
          _extractString(fields['estate_name']) ?? '',
          _extractInt(fields['quantity']) ?? 0,
          _extractDouble(fields['unit_price']) ?? 0.0,
          _extractString(fields['image_path']) ?? '',
          _extractString(fields['company_id']) ?? '',
          _extractInt(fields['is_active']) ?? 1,
          1,
          _extractString(fields['created_at']) ?? DateTime.now().toIso8601String(),
          _extractString(fields['updated_at']) ?? DateTime.now().toIso8601String(),
          _extractString(fields['status']) ?? 'pending',
        ],
      );
    } catch (e) {
      debugPrint('❌ Error saving trading entry: $e');
    }
  }
}

// ✅ Save Working Progress
Future<void> _saveWorkingProgressToLocal(List documents) async {
  final db = await AppDatabase.instance();
  for (final doc in documents) {
    final docName = doc['name'] as String;
    final docId = docName.split('/').last;
    final fields = doc['fields'] as Map<String, dynamic>;
    
    try {
      await db.customStatement(
        '''INSERT OR REPLACE INTO working_progress (
          id, company_id, name, status, remarks, from_user, to_user,
          transfer_date, next_working_date, category, source, is_active,
          updated_at, is_synced
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          docId,
          _extractString(fields['company_id']) ?? _extractString(fields['companyId']),
          _extractString(fields['name']) ?? '',
          _extractString(fields['status']) ?? 'Pending',
          _extractString(fields['remarks']),
          _extractString(fields['from_user']),
          _extractString(fields['to_user']),
          _extractString(fields['transfer_date']),
          _extractString(fields['next_working_date']),
          _extractString(fields['category']),
          _extractString(fields['source']) ?? 'Agent',
          _extractInt(fields['is_active']) ?? 1,
          _extractString(fields['updated_at']) ?? DateTime.now().toIso8601String(),
          1,
        ],
      );
    } catch (e) {
      debugPrint('❌ Error saving working progress: $e');
    }
  }
}

// ✅ Save Expenditures
Future<void> _saveExpendituresToLocal(List documents) async {
  final db = await AppDatabase.instance();
  for (final doc in documents) {
    final docName = doc['name'] as String;
    final docId = docName.split('/').last;
    final fields = doc['fields'] as Map<String, dynamic>;
    
    try {
      await db.customStatement(
        '''INSERT OR REPLACE INTO expenditures (
          id, date, description, amount, category, company_id, created_by,
          kind, project_id, category_id, office_month, category_type,
          created_at, updated_at, is_active, is_synced
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          docId,
          _extractString(fields['date']) ?? DateTime.now().toIso8601String(),
          _extractString(fields['description']) ?? '',
          _extractDouble(fields['amount']) ?? 0.0,
          _extractString(fields['category']) ?? '',
          _extractString(fields['company_id']) ?? '',
          _extractString(fields['created_by']) ?? '',
          _extractString(fields['kind']) ?? '',
          _extractString(fields['project_id']),
          _extractString(fields['category_id']),
          _extractString(fields['office_month']),
          _extractString(fields['category_type']),
          _extractString(fields['created_at']) ?? DateTime.now().toIso8601String(),
          _extractString(fields['updated_at']) ?? DateTime.now().toIso8601String(),
          _extractInt(fields['is_active']) ?? 1,
          1,
        ],
      );
    } catch (e) {
      debugPrint('❌ Error saving expenditure: $e');
    }
  }
}

// ✅ Save Inventory Files
Future<void> _saveInventoryFilesToLocal(List documents) async {
  final db = await AppDatabase.instance();
  for (final doc in documents) {
    final docName = doc['name'] as String;
    final docId = docName.split('/').last;
    final fields = doc['fields'] as Map<String, dynamic>;
    
    try {
      await db.customStatement(
        '''INSERT OR REPLACE INTO files_table (
          id, name, client_name, file_no, demand, sale_status,
          society_id, block_id, company_id, is_active, updated_at, is_synced
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          docId,
          _extractString(fields['name']) ?? '',
          _extractString(fields['client_name']),
          _extractString(fields['file_no']),
          _extractInt(fields['demand']) ?? 0,
          _extractString(fields['sale_status']),
          _extractString(fields['society_id']),
          _extractString(fields['block_id']),
          _extractString(fields['company_id']) ?? '',
          _extractInt(fields['is_active']) ?? 1,
          _extractString(fields['updated_at']) ?? DateTime.now().toIso8601String(),
          1,
        ],
      );
    } catch (e) {
      debugPrint('❌ Error saving inventory file: $e');
    }
  }
}

// ✅ Save Rental Items
Future<void> _saveRentalItemsToLocal(List documents) async {
  final db = await AppDatabase.instance();
  for (final doc in documents) {
    final docName = doc['name'] as String;
    final docId = docName.split('/').last;
    final fields = doc['fields'] as Map<String, dynamic>;
    
    try {
      await db.customStatement(
        '''INSERT OR REPLACE INTO rental_items (
          id, name, rent_amount, company_id, is_active,
          created_at, updated_at, is_synced
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          docId,
          _extractString(fields['name']) ?? '',
          _extractDouble(fields['rent_amount']) ?? 0.0,
          _extractString(fields['company_id']) ?? '',
          _extractInt(fields['is_active']) ?? 1,
          _extractString(fields['created_at']) ?? DateTime.now().toIso8601String(),
          _extractString(fields['updated_at']) ?? DateTime.now().toIso8601String(),
          1,
        ],
      );
    } catch (e) {
      debugPrint('❌ Error saving rental item: $e');
    }
  }
}

// ✅ Save Reminders
Future<void> _saveRemindersToLocal(List documents) async {
  final db = await AppDatabase.instance();
  for (final doc in documents) {
    final docName = doc['name'] as String;
    final docId = docName.split('/').last;
    final fields = doc['fields'] as Map<String, dynamic>;
    
    try {
      await db.customStatement(
        '''INSERT OR REPLACE INTO reminders (
          id, title, description, due_date, user_id, company_id,
          is_completed, is_active, created_at, updated_at, is_synced
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          docId,
          _extractString(fields['title']) ?? '',
          _extractString(fields['description']) ?? '',
          _extractString(fields['due_date']) ?? DateTime.now().toIso8601String(),
          _extractString(fields['user_id']) ?? '',
          _extractString(fields['company_id']) ?? '',
          _extractInt(fields['is_completed']) ?? 0,
          _extractInt(fields['is_active']) ?? 1,
          _extractString(fields['created_at']) ?? DateTime.now().toIso8601String(),
          _extractString(fields['updated_at']) ?? DateTime.now().toIso8601String(),
          1,
        ],
      );
    } catch (e) {
      debugPrint('❌ Error saving reminder: $e');
    }
  }
}

// ✅ Helper for double extraction
double? _extractDouble(dynamic field) {
  if (field == null) return null;
  if (field is Map) {
    if (field.containsKey('nullValue')) return null;
    if (field.containsKey('doubleValue')) {
      return double.tryParse(field['doubleValue'].toString());
    }
    if (field.containsKey('integerValue')) {
      return double.tryParse(field['integerValue'].toString());
    }
  }
  return double.tryParse(field.toString());
}
  
  // Helper methods to extract Firestore REST API values
 // ✅ FIXED: Handle Firestore nullValue properly
String? _extractString(dynamic field) {
  if (field == null) return null;
  
  if (field is Map) {
    // ✅ CRITICAL: Check for nullValue (Firestore REST API null representation)
    if (field.containsKey('nullValue')) {
      return null;  // ✅ Return null, not the string "{nullValue: null}"
    }
    if (field.containsKey('stringValue')) {
      final value = field['stringValue'];
      return value?.toString();
    }
    if (field.containsKey('integerValue')) {
      return field['integerValue']?.toString();
    }
    if (field.containsKey('booleanValue')) {
      return field['booleanValue']?.toString();
    }
    if (field.containsKey('timestampValue')) {
      return field['timestampValue']?.toString();
    }
  }
  
  // ✅ CRITICAL: If it's already a string, check if it's a null representation
  if (field is String) {
    if (field.contains('nullValue') || field == 'null') {
      return null;
    }
    return field;
  }
  
  return field?.toString();
}
  
  int? _extractInt(dynamic field) {
    if (field == null) return null;
    if (field is Map && field.containsKey('integerValue')) {
      return int.tryParse(field['integerValue'].toString());
    }
    return int.tryParse(field.toString());
  }
}