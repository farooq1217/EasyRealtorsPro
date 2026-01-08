# Firebase Syncing Guide

This guide explains how data syncing works between SQLite (local) and Firebase (cloud) in your application.

---

## Architecture Overview

### Desktop App (Windows)
- **Primary Database**: SQLite (via Drift)
- **Cloud Database**: Firestore
- **Sync Strategy**: Manual sync (on-demand) + Real-time for notes

### Mobile App (Android/iOS)
- **Primary Database**: SQLite (via sqflite)
- **Cloud Database**: Firebase Realtime Database
- **Sync Strategy**: Automatic sync + Offline-first with queue

---

## Current Sync Implementation

### Mobile App (`packages/mobile_admin`)

#### ✅ Already Implemented:
1. **SyncProvider** - Handles bidirectional sync
2. **Real-time Listeners** - Listens to Firebase for updates
3. **Offline Queue** - Stores changes when offline, syncs when online
4. **Auto-sync on Login** - Syncs all data when user logs in

#### Synced Tables:
- `files_table` → `firebase/files_table`
- `properties` → `firebase/properties`
- `rental_items` → `firebase/rental_items`
- `working_progress` → `firebase/working_progress`
- `reminders` → `firebase/reminders`

#### How It Works:
1. **On App Start**: Real-time listeners connect to Firebase
2. **On Data Change (Firebase → Local)**:
   - Firebase sends update
   - Local SQLite is updated
   - UI refreshes automatically
3. **On Data Change (Local → Firebase)**:
   - Data saved to local SQLite first
   - Attempts to push to Firebase
   - If offline, queues in `pending_sync` table
   - When online, automatically flushes queue

---

## Desktop App Syncing

### Current Implementation:
- **Agent Working Notes**: Uses Firestore (real-time)
  - Office Work notes → `agent_working/office_notes/notes`
  - Other Work notes → `agent_working/other_notes/notes`

### To Be Implemented:
- **Transfer & Client Requirements**: Currently only saved to SQLite
- **Full Data Sync**: All SQLite tables → Firestore

---

## Data Flow Diagrams

### Mobile App (Offline-First)
```
User Action
    ↓
Save to SQLite (immediate)
    ↓
Is Online?
    ├─ Yes → Push to Firebase → Success
    └─ No → Queue in pending_sync
            ↓
        When Online → Auto-flush queue
```

### Desktop App (On-Demand)
```
User Action
    ↓
Save to SQLite (immediate)
    ↓
Manual Sync Button
    ↓
Push to Firestore
```

---

## Firebase Database Structure

### Realtime Database (Mobile)
```
{
  "files_table": {
    "{id}": { /* file data */ }
  },
  "properties": {
    "{id}": { /* property data */ }
  },
  "rental_items": {
    "{id}": { /* rental data */ }
  },
  "working_progress": {
    "{id}": { /* working progress data */ }
  },
  "reminders": {
    "{pushId}": { /* reminder data */ }
  },
  "agent_working": {
    "office_notes": {
      "{pushId}": {
        "text": "...",
        "createdAt": ServerTimestamp
      }
    },
    "other_notes": {
      "{pushId}": {
        "text": "...",
        "createdAt": ServerTimestamp
      }
    }
  }
}
```

### Firestore (Desktop)
```
agent_working/
  ├── office_notes/
  │   └── notes/
  │       └── {docId}/
  │           ├── text: string
  │           └── createdAt: Timestamp
  └── other_notes/
      └── notes/
          └── {docId}/
              ├── text: string
              └── createdAt: Timestamp

working_progress/ (to be added)
  └── entries/
      └── {docId}/
          ├── id: string
          ├── name: string
          ├── status: string
          ├── remarks: string
          ├── transferDate: string
          ├── nextWorkingDate: string
          └── updatedAt: string
```

---

## Syncing Agent Working Data

### Mobile App
✅ **Already Working**: `working_progress` table syncs automatically via `SyncProvider`

### Desktop App
**Current Status**: Transfer and Client Requirements forms save to SQLite only

**To Enable Firebase Sync** (Future Enhancement):
1. Add Firestore collection: `working_progress/entries`
2. On form submit, save to both SQLite and Firestore
3. Add sync button to push all SQLite data to Firestore

---

## Testing Sync

### Mobile App
1. **Test Online Sync**:
   - Add/edit data → Check Firebase Console
   - Data should appear immediately

2. **Test Offline Queue**:
   - Turn off internet
   - Add/edit data → Check `pending_sync` table
   - Turn on internet → Data should sync automatically

3. **Test Real-time Updates**:
   - Open app on two devices
   - Add data on device 1 → Device 2 should update automatically

### Desktop App
1. **Test Notes Sync**:
   - Add Office Work note → Check Firestore Console
   - Note should appear in `agent_working/office_notes/notes`

2. **Test Transfer/Client Requirements** (when implemented):
   - Submit form → Check Firestore Console
   - Entry should appear in `working_progress/entries`

---

## Troubleshooting

### Mobile: "Sync failed"
- Check internet connection
- Verify Firebase configuration
- Check Realtime Database rules
- Check `pending_sync` table for queued items

### Mobile: "Data not syncing"
- Check `SyncProvider` listeners are started
- Verify Firebase initialization
- Check for errors in console

### Desktop: "Notes not saving"
- Check Firestore rules allow write
- Verify Firestore is enabled in Firebase Console
- Check network connection

### Desktop: "Transfer/Client Requirements not syncing"
- Currently only saves to SQLite
- Need to implement Firestore sync (future enhancement)

---

## Future Enhancements

### Desktop App
1. **Add Firestore Sync for Working Progress**:
   - Save Transfer/Client Requirements to Firestore
   - Add sync button to push all SQLite data
   - Add real-time listeners for updates

2. **Full Data Migration**:
   - Export all SQLite tables to Firestore
   - Set up bidirectional sync
   - Handle conflicts (last-write-wins or merge)

### Mobile App
1. **Enhanced Conflict Resolution**:
   - Implement merge strategies
   - Add conflict resolution UI
   - Track sync status per record

2. **Background Sync**:
   - Sync in background when app is closed
   - Periodic sync when app is idle
   - Sync on network reconnection

---

## Security Considerations

### Current Rules (Development)
- **Realtime Database**: `{ ".read": true, ".write": true }`
- **Firestore**: `allow read, write: if true`

### Production Rules (Recommended)
- Implement Firebase Authentication
- Restrict access based on user roles
- Validate data structure
- Set up proper indexes
- Implement rate limiting

---

## Monitoring Sync Status

### Mobile App
- Check `pending_sync` table for queued items
- Monitor `SyncProvider.lastError` for errors
- Check Firebase Console for data

### Desktop App
- Check Firestore Console for data
- Monitor console for errors
- Check SQLite database for local data

---

## Best Practices

1. **Always save to local first** (offline-first approach)
2. **Queue changes when offline** (mobile app)
3. **Sync on app start** (mobile app)
4. **Provide manual sync option** (desktop app)
5. **Handle errors gracefully** (show user-friendly messages)
6. **Monitor sync status** (show progress indicators)
7. **Test offline scenarios** (ensure app works without internet)

---

## Next Steps

1. ✅ Mobile app sync is working
2. ✅ Desktop app notes sync is working
3. ⏳ Desktop app Transfer/Client Requirements sync (to be implemented)
4. ⏳ Full data migration script (to be created)
5. ⏳ Conflict resolution (to be implemented)
6. ⏳ Production security rules (to be configured)

