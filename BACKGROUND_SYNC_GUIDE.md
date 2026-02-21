# Background Sync Implementation Guide

## Overview

The EasyRealtorsPro application now includes a comprehensive background sync system that automatically synchronizes local database changes with Firestore when internet connectivity is restored. This ensures data integrity across offline and online scenarios.

## Architecture

### Core Components

1. **Database Schema Updates**
   - Added `is_synced` column to all tables (boolean, default: true)
   - Schema version updated to 24 with automatic migration
   - New records start with `is_synced = 0` (pending sync)

2. **BackgroundSyncManager**
   - Monitors internet connectivity using `connectivity_plus`
   - Automatically triggers sync when internet is restored
   - Periodic sync checks every 5 minutes
   - Batch sync operations for efficiency

3. **SyncDatabaseHelper**
   - Utility class for marking records as unsynced
   - Helper methods for INSERT/UPDATE/DELETE operations
   - Batch operations support

4. **Integration Points**
   - Initialized in `AdminApp` (app.dart)
   - Automatically disposed when app closes
   - Works alongside existing Firestore sync

## Implementation Details

### Database Schema Changes

All tables now include:
```sql
is_synced INTEGER NOT NULL DEFAULT 1  -- 0 = pending sync, 1 = synced
```

Tables updated:
- Core tables: companies, users, societies, blocks, properties, files_table, rental_items, working_progress, reminders, clients
- Business tables: trading_entries, trading_file_entries, expenditures

### Sync Manager Features

1. **Connectivity Monitoring**
   - Real-time internet status tracking
   - Automatic sync trigger on connection restore
   - Graceful handling of connection loss

2. **Incremental Sync**
   - Only syncs records with `is_synced = 0`
   - Batch operations for efficiency
   - Error handling and retry logic

3. **Background Processing**
   - Runs in background without blocking UI
   - Periodic sync checks (5-minute intervals)
   - Status tracking for each table

## Usage Patterns

### For Database Operations

#### 1. Using SyncDatabaseHelper (Recommended)

```dart
import '../../core/services/sync_database_helper.dart';

class YourPage extends StatefulWidget {
  final SyncDatabaseHelper _syncHelper = SyncDatabaseHelper();
  
  // INSERT operation
  Future<void> addRecord(Map<String, dynamic> data) async {
    data['is_synced'] = 0; // Mark as pending sync
    final recordId = await _syncHelper.insertWithSyncMark('your_table', data);
    
    if (recordId != null) {
      // Success - record will be synced automatically
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Record added successfully')),
      );
    }
  }
  
  // UPDATE operation
  Future<void> updateRecord(String recordId, Map<String, dynamic> data) async {
    final success = await _syncHelper.updateWithSyncMark('your_table', recordId, data);
    
    if (success) {
      // Success - record will be synced automatically
      await _loadData(); // Refresh UI
    }
  }
  
  // DELETE operation
  Future<void> deleteRecord(String recordId) async {
    final success = await _syncHelper.deleteWithSyncMark('your_table', recordId);
    
    if (success) {
      // Success - deletion will be synced automatically
      await _loadData(); // Refresh UI
    }
  }
}
```

#### 2. Manual Sync Marking

```dart
// After custom database operations
await widget.db.customStatement(
  'UPDATE your_table SET column = ? WHERE id = ?',
  [newValue, recordId],
);

// Mark as unsynced
await _syncHelper.markAsUnsynced('your_table', recordId);
```

#### 3. Raw SQL with Sync Flag

```dart
// Include is_synced = 0 in INSERT statements
await widget.db.customStatement(
  'INSERT INTO your_table (id, name, is_synced) VALUES (?, ?, 0)',
  [recordId, name],
);

// Include is_synced = 0 in UPDATE statements
await widget.db.customStatement(
  'UPDATE your_table SET name = ?, is_synced = 0 WHERE id = ?',
  [newName, recordId],
);
```

### Monitoring Sync Status

```dart
import '../../core/services/background_sync_manager.dart';

// Get sync manager instance
final syncManager = BackgroundSyncManager();

// Check if internet is available
bool hasInternet = syncManager.hasInternet;

// Check if sync is in progress
bool isSyncing = syncManager.isSyncing;

// Get sync status for all tables
Map<String, SyncStatus> status = syncManager.syncStatus;
print('Users table sync status: ${status['users']}');

// Check if there are unsynced records
bool hasUnsynced = await syncManager.hasUnsyncedRecords();

// Force manual sync
await syncManager.forceSync();
```

## Migration Guide

### For Existing Database Operations

1. **Add Sync Helper Import**
```dart
import '../../core/services/sync_database_helper.dart';
```

2. **Initialize Sync Helper**
```dart
class _YourPageState extends State<YourPage> {
  final SyncDatabaseHelper _syncHelper = SyncDatabaseHelper();
  // ... rest of your code
}
```

3. **Update INSERT Operations**
```dart
// Before
await widget.db.customStatement(
  'INSERT INTO users (name, email) VALUES (?, ?)',
  [name, email],
);

// After
await _syncHelper.insertWithSyncMark('users', {
  'id': userId,
  'name': name,
  'email': email,
  'created_at': DateTime.now().toIso8601String(),
  'updated_at': DateTime.now().toIso8601String(),
});
```

4. **Update UPDATE Operations**
```dart
// Before
await widget.db.customStatement(
  'UPDATE users SET name = ? WHERE id = ?',
  [newName, userId],
);

// After
await _syncHelper.updateWithSyncMark('users', userId, {
  'name': newName,
  'updated_at': DateTime.now().toIso8601String(),
});
```

5. **Update DELETE Operations**
```dart
// Before
await widget.db.customStatement('DELETE FROM users WHERE id = ?', [userId]);

// After
await _syncHelper.deleteWithSyncMark('users', userId);
```

## Best Practices

### 1. Always Mark Records as Unsynced
Every local change should be marked for sync:
```dart
// After any database modification
await _syncHelper.markAsUnsynced('table_name', recordId);
```

### 2. Use Helper Methods When Possible
The sync helper provides convenient methods that handle the sync marking automatically:
```dart
// Preferred
await _syncHelper.insertWithSyncMark('table', data);

// Alternative
await _syncHelper.markAsUnsynced('table', recordId);
```

### 3. Handle Sync Errors Gracefully
The sync system includes error handling, but monitor sync status:
```dart
if (syncManager.syncStatus['users']?.lastError != null) {
  // Show sync error to user
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Sync failed: ${syncManager.syncStatus['users']?.lastError}'),
      backgroundColor: Colors.red,
    ),
  );
}
```

### 4. Provide User Feedback
Let users know when data is being synced:
```dart
// Check sync status in your UI
StreamBuilder(
  stream: syncManager.syncStatusStream,
  builder: (context, snapshot) {
    final isSyncing = syncManager.isSyncing;
    return IconButton(
      icon: Icon(
        isSyncing ? Icons.sync : Icons.sync_disabled,
        color: isSyncing ? Colors.orange : Colors.grey,
      ),
      onPressed: () async {
        await syncManager.forceSync();
      },
    );
  },
)
```

## Troubleshooting

### Common Issues

1. **Records Not Syncing**
   - Check if `is_synced` column exists (run migration)
   - Verify internet connectivity
   - Check Firestore authentication

2. **Migration Issues**
   - Ensure schema version is incremented
   - Check migration logic in `_safeAddIsSyncedColumns`

3. **Performance Issues**
   - Use batch operations for bulk changes
   - Limit sync frequency with periodic checks
   - Monitor sync queue size

### Debug Information

Enable debug logging to monitor sync operations:
```dart
// Sync operations are logged with [SYNC] prefix
// Check console for detailed sync information
```

### Testing Scenarios

1. **Offline to Online Transition**
   - Disconnect internet
   - Make local changes
   - Reconnect internet
   - Verify automatic sync

2. **Batch Operations**
   - Create multiple records offline
   - Reconnect internet
   - Verify batch sync efficiency

3. **Error Handling**
   - Simulate sync failures
   - Verify retry logic
   - Check error reporting

## Dependencies

Add to `pubspec.yaml`:
```yaml
dependencies:
  connectivity_plus: ^6.1.0  # Already added
```

## Future Enhancements

1. **Conflict Resolution**
   - Implement merge strategies for conflicting changes
   - User interface for resolving conflicts

2. **Selective Sync**
   - Allow users to choose which data to sync
   - Priority-based sync scheduling

3. **Sync Analytics**
   - Track sync performance metrics
   - Monitor sync success rates

4. **Background Sync Isolate**
   - Move sync operations to background isolate
   - Improve UI responsiveness during sync

## Conclusion

The background sync system provides a robust foundation for offline-first data management. By following the patterns and best practices outlined in this guide, you can ensure that all local changes are properly synchronized with Firestore when connectivity is restored.
