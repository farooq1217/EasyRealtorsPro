import 'dart:io';
import 'dart:convert';

Future<void> main() async {
  try {
    final dbPath = '${Platform.environment['LOCALAPPDATA']}\\EasyRealtorsPro\\data.sqlite';
    final dbFile = File(dbPath);
    
    if (!await dbFile.exists()) {
      print('❌ Database file not found at: $dbPath');
      return;
    }
    
    print('📁 Database found at: $dbPath');
    
    // Read SQLite database to check asad@gmail.com permissions
    final content = await dbFile.readAsString();
    final lines = content.split('\n');
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.contains('asad@gmail.com') && line.contains('permissionsMap')) {
        print('\n📋 User asad@gmail.com permissions found:');
        print('Line ${i + 1}: $line');
        
        // Try to extract and parse the permissions
        final permissionsMatch = RegExp(r'permissionsMap":\{([^}]+)\}').firstMatch(line);
        if (permissionsMatch != null) {
          final permissionsJson = '{${permissionsMatch.group(1)}}';
          print('📄 Parsed permissions: $permissionsJson');
          
          try {
            final permissions = jsonDecode(permissionsJson);
            print('✅ Available modules:');
            final permissionsMap = permissions['permissionsMap'] as Map<String, dynamic>? ?? {};
            permissionsMap.forEach((key, value) {
              print('   - $key: $value');
            });
          } catch (e) {
            print('❌ Error parsing permissions: $e');
          }
        }
        break;
      }
    }
    
  } catch (e) {
    print('❌ Error: $e');
  }
}
