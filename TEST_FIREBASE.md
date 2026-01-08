# Firebase Integration Testing Guide

## Current Status

The Firebase configuration files (`firebase_options.dart`) still have placeholder values. To test Firebase integration, you need to:

1. **Update Firebase Configuration** (see QUICK_FIREBASE_SETUP.md)
2. **Enable Databases** in Firebase Console
3. **Run Tests**

## Testing Steps

### Step 1: Verify Configuration

Run the test script:
```bash
cd packages/desktop_admin
dart run test_firebase.dart
```

**Expected Output if NOT configured:**
```
❌ ERROR: Firebase configuration still has placeholder values!
Please update firebase_options.dart with real values from Firebase Console.
```

**Expected Output if configured:**
```
✅ Configuration looks valid (no placeholders found)
✅ Firebase initialized successfully!
✅ Firestore connection successful!
```

### Step 2: Test in App

Once configured, run the app:
```bash
cd packages/desktop_admin
flutter run -d windows
```

### Step 3: Test Each Feature

#### Test 1: Office Work Notes
1. Navigate to: **Agent Working** → **Office Work**
2. Enter a note in the text field
3. Click **"Save Note"**
4. **Expected**: Note appears below immediately
5. **Verify**: Check Firestore Console → `agent_working/office_notes/notes` collection

#### Test 2: Other Work Notes
1. Navigate to: **Agent Working** → **Other Work**
2. Enter a note in the text field
3. Click **"Save Note"**
4. **Expected**: Note appears below immediately
5. **Verify**: Check Firestore Console → `agent_working/other_notes/notes` collection

#### Test 3: Transfer Form
1. Navigate to: **Agent Working** → **Transfer**
2. Fill in the form:
   - Select Category (e.g., Plot)
   - Select Date
   - Enter Plot No.
   - Enter Client Name
   - Enter Client Mobile No.
   - Select Time
   - Enter Registry/Transfer Number
   - (Optional) Add Comment
   - (Optional) Select Next Working Date
3. Click **"Complete"** or **"Close Without Complete"**
4. **Expected**: Success message, form resets, entry appears in "Saved Entries"
5. **Verify**: 
   - Check SQLite database (local)
   - Check Firestore Console → `working_progress/{id}` collection
   - Entry should have `type: 'transfer'`

#### Test 4: Client Requirements Form
1. Navigate to: **Agent Working** → **Client Requirements**
2. Fill in the form (same fields as Transfer)
3. Click **"Complete"** or **"Close Without Complete"**
4. **Expected**: Success message, form resets, entry appears in "Saved Entries"
5. **Verify**: 
   - Check SQLite database (local)
   - Check Firestore Console → `working_progress/{id}` collection
   - Entry should have `type: 'client_requirement'`

#### Test 5: Notification System
1. Create an entry with **Next Working Date** = Today's date
2. Close and reopen the Agent Working module
3. **Expected**: Notification dialog appears showing the entry due today

### Step 4: Verify in Firebase Console

#### Firestore (Desktop)
1. Go to Firebase Console → Firestore Database
2. Check collections:
   - `agent_working/office_notes/notes` - Should have notes
   - `agent_working/other_notes/notes` - Should have notes
   - `working_progress` - Should have transfer/client requirement entries

#### Realtime Database (Mobile - if testing mobile app)
1. Go to Firebase Console → Realtime Database
2. Check nodes:
   - `agent_working/office_notes` - Should have notes
   - `agent_working/other_notes` - Should have notes
   - `working_progress` - Should have entries

## Troubleshooting

### Issue: "Firebase not initialized"
**Solution**: Check `firebase_options.dart` has real values (not "TODO")

### Issue: "Permission denied"
**Solution**: 
- Firestore: Set rules to `allow read, write: if true;`
- Realtime Database: Set rules to `{ ".read": true, ".write": true }`

### Issue: Notes not saving
**Solution**:
- Check Firestore Console for errors
- Verify Firestore is enabled
- Check network connection
- Check security rules

### Issue: Transfer/Client Requirements not syncing to Firestore
**Solution**:
- Check console for errors (they're logged silently)
- Verify Firebase is initialized (`Firebase.apps.isNotEmpty`)
- Check Firestore rules allow write

## Test Checklist

- [ ] Firebase configuration updated (no placeholders)
- [ ] Firestore Database created and enabled
- [ ] Firestore rules set to allow read/write
- [ ] Test script passes
- [ ] App runs without Firebase errors
- [ ] Office Work notes save to Firestore
- [ ] Other Work notes save to Firestore
- [ ] Transfer forms save to Firestore
- [ ] Client Requirements forms save to Firestore
- [ ] Data visible in Firebase Console
- [ ] Notification system works (entries due today)

## Next: Mobile App Testing

After desktop testing, test mobile app:
```bash
cd packages/mobile_admin
dart run test_firebase.dart
flutter run
```

Test offline functionality:
1. Turn off internet
2. Add data → Should save to local SQLite
3. Turn on internet → Should sync automatically to Realtime Database

