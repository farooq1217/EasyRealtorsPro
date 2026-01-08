# Firebase Manual Setup Guide

This guide will help you manually configure Firebase for both Desktop and Mobile apps.

## Prerequisites
- Firebase account (create at https://console.firebase.google.com/)
- Node.js installed (for Firebase CLI) - https://nodejs.org/

---

## Part 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **"Add project"** or select an existing project
3. Enter project name (e.g., "Real Estate Admin")
4. Follow the setup wizard:
   - Enable/disable Google Analytics (optional)
   - Choose Analytics account (if enabled)
5. Click **"Create project"** and wait for setup to complete

---

## Part 2: Enable Firestore Database (for Desktop App)

1. In Firebase Console, go to **Firestore Database**
2. Click **"Create database"**
3. Choose **"Start in test mode"** (we'll set rules later)
4. Select a **location** (choose closest to your users)
5. Click **"Enable"**
6. Wait for database creation

**Firestore Rules (for development):**
Go to Firestore Database → Rules tab, set:
```json
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```
Click **"Publish"**

---

## Part 3: Enable Realtime Database (for Mobile App)

1. In Firebase Console, go to **Realtime Database**
2. Click **"Create Database"**
3. Choose **"Start in test mode"**
4. Select a **location** (choose closest to your users)
5. Click **"Enable"**

**Realtime Database Rules (for development):**
Go to Realtime Database → Rules tab, set:
```json
{
  "rules": {
    ".read": true,
    ".write": true
  }
}
```
Click **"Publish"**

---

## Part 4: Register Desktop App (Windows)

1. In Firebase Console, go to **Project Settings** (gear icon)
2. Scroll to **"Your apps"** section
3. Click **"Add app"** → Select **Windows** icon
4. Register app:
   - **App nickname**: "Desktop Admin" (optional)
   - **App ID**: Leave default or enter custom
5. Click **"Register app"**
6. **Copy these values** (you'll need them):
   - `apiKey`
   - `appId` (format: `1:123456789:windows:abc123def456`)
   - `messagingSenderId`
   - `projectId`
   - `databaseURL` (from Realtime Database section - but we'll use Firestore)

---

## Part 5: Register Desktop App (Web - Optional)

1. In Firebase Console → Project Settings → Your apps
2. Click **"Add app"** → Select **Web** icon (`</>`)
3. Register app:
   - **App nickname**: "Desktop Admin Web"
   - **Firebase Hosting**: Skip for now
4. Click **"Register app"**
5. **Copy these values**:
   - `apiKey`
   - `appId`
   - `messagingSenderId`
   - `projectId`
   - `authDomain`
   - `databaseURL` (from Realtime Database - but we'll use Firestore)
   - `storageBucket`
   - `measurementId` (if Analytics enabled)

---

## Part 6: Register Mobile App (Android)

1. In Firebase Console → Project Settings → Your apps
2. Click **"Add app"** → Select **Android** icon
3. Register app:
   - **Android package name**: Check `packages/mobile_admin/android/app/build.gradle` for `applicationId`
     - Usually: `com.example.mobile_admin` or similar
   - **App nickname**: "Mobile Admin" (optional)
   - **Debug signing certificate**: Skip for now
4. Click **"Register app"**
5. Download `google-services.json`:
   - Click **"Download google-services.json"**
   - Save to: `packages/mobile_admin/android/app/google-services.json`
6. **Copy these values**:
   - `apiKey`
   - `appId`
   - `messagingSenderId`
   - `projectId`
   - `databaseURL` (from Realtime Database section)

---

## Part 7: Register Mobile App (iOS)

1. In Firebase Console → Project Settings → Your apps
2. Click **"Add app"** → Select **iOS** icon
3. Register app:
   - **iOS bundle ID**: Check `packages/mobile_admin/ios/Runner.xcodeproj` or `Info.plist`
     - Usually: `com.example.mobileAdmin` or similar
   - **App nickname**: "Mobile Admin iOS" (optional)
   - **App Store ID**: Skip for now
4. Click **"Register app"**
5. Download `GoogleService-Info.plist`:
   - Click **"Download GoogleService-Info.plist"**
   - Save to: `packages/mobile_admin/ios/Runner/GoogleService-Info.plist`
6. **Copy these values**:
   - `apiKey`
   - `appId`
   - `messagingSenderId`
   - `projectId`
   - `databaseURL` (from Realtime Database section)

---

## Part 8: Update Desktop Admin Firebase Options

Edit `packages/desktop_admin/lib/firebase_options.dart`:

### Windows Configuration:
```dart
static const FirebaseOptions windows = FirebaseOptions(
  apiKey: 'YOUR_WINDOWS_API_KEY',  // From Part 4
  appId: 'YOUR_WINDOWS_APP_ID',     // From Part 4 (format: 1:123456789:windows:abc123)
  messagingSenderId: 'YOUR_SENDER_ID',  // From Part 4
  projectId: 'YOUR_PROJECT_ID',     // From Part 4
  databaseURL: 'https://YOUR_PROJECT_ID-default-rtdb.firebaseio.com',  // Optional for Firestore
  storageBucket: 'YOUR_PROJECT_ID.appspot.com',  // From Project Settings
);
```

### Web Configuration (if needed):
```dart
static const FirebaseOptions web = FirebaseOptions(
  apiKey: 'YOUR_WEB_API_KEY',      // From Part 5
  appId: 'YOUR_WEB_APP_ID',         // From Part 5
  messagingSenderId: 'YOUR_SENDER_ID',  // From Part 5
  projectId: 'YOUR_PROJECT_ID',     // From Part 5
  authDomain: 'YOUR_PROJECT_ID.firebaseapp.com',  // From Part 5
  databaseURL: 'https://YOUR_PROJECT_ID-default-rtdb.firebaseio.com',  // Optional
  storageBucket: 'YOUR_PROJECT_ID.appspot.com',  // From Part 5
  measurementId: 'G-XXXXXXXXXX',   // From Part 5 (if Analytics enabled)
);
```

**Note:** For Firestore, `databaseURL` is optional but can be kept for compatibility.

---

## Part 9: Update Mobile Admin Firebase Options

Edit `packages/mobile_admin/lib/firebase_options.dart`:

### Android Configuration:
```dart
static const FirebaseOptions android = FirebaseOptions(
  apiKey: 'YOUR_ANDROID_API_KEY',  // From Part 6
  appId: 'YOUR_ANDROID_APP_ID',    // From Part 6 (format: 1:123456789:android:abc123)
  messagingSenderId: 'YOUR_SENDER_ID',  // From Part 6
  projectId: 'YOUR_PROJECT_ID',    // From Part 6
  databaseURL: 'https://YOUR_PROJECT_ID-default-rtdb.firebaseio.com',  // From Realtime Database
  storageBucket: 'YOUR_PROJECT_ID.appspot.com',  // From Part 6
);
```

### iOS Configuration:
```dart
static const FirebaseOptions ios = FirebaseOptions(
  apiKey: 'YOUR_IOS_API_KEY',      // From Part 7
  appId: 'YOUR_IOS_APP_ID',         // From Part 7 (format: 1:123456789:ios:abc123)
  messagingSenderId: 'YOUR_SENDER_ID',  // From Part 7
  projectId: 'YOUR_PROJECT_ID',    // From Part 7
  databaseURL: 'https://YOUR_PROJECT_ID-default-rtdb.firebaseio.com',  // From Realtime Database
  storageBucket: 'YOUR_PROJECT_ID.appspot.com',  // From Part 7
  iosBundleId: 'YOUR_BUNDLE_ID',   // From Part 7 (e.g., com.example.mobileAdmin)
);
```

---

## Part 10: Verify Configuration

### Check Desktop App:
1. Open `packages/desktop_admin/lib/firebase_options.dart`
2. Verify all `TODO_*` placeholders are replaced with real values
3. Run: `cd packages/desktop_admin && flutter run -d windows`
4. Test: Agent Working → Office Work → Add a note
5. Check Firestore Console → `agent_working/office_notes/notes` collection

### Check Mobile App:
1. Open `packages/mobile_admin/lib/firebase_options.dart`
2. Verify all `TODO_*` placeholders are replaced with real values
3. Ensure `google-services.json` is in `android/app/`
4. Ensure `GoogleService-Info.plist` is in `ios/Runner/`
5. Run: `cd packages/mobile_admin && flutter run`
6. Test: Agent Working → Office Work → Add a note
7. Check Realtime Database Console → `agent_working/office_notes` node

---

## Part 11: Database Structure

### Firestore (Desktop) Structure:
```
agent_working/
  ├── office_notes/
  │   └── notes/
  │       ├── {docId}/
  │       │   ├── text: "Note content"
  │       │   └── createdAt: Timestamp
  │       └── ...
  └── other_notes/
      └── notes/
          ├── {docId}/
          │   ├── text: "Note content"
          │   └── createdAt: Timestamp
          └── ...
```

### Realtime Database (Mobile) Structure:
```
agent_working/
  ├── office_notes/
  │   ├── {pushId}/
  │   │   ├── text: "Note content"
  │   │   └── createdAt: ServerTimestamp
  │   └── ...
  └── other_notes/
      ├── {pushId}/
      │   ├── text: "Note content"
      │   └── createdAt: ServerTimestamp
      └── ...
```

---

## Troubleshooting

### Error: "Firebase not initialized"
- Check that `firebase_options.dart` has real values (not "TODO")
- Verify `Firebase.initializeApp()` is called in `main()`

### Error: "Permission denied"
- Check Firestore/Realtime Database rules
- Ensure rules allow read/write (for development)

### Error: "Missing google-services.json"
- Ensure file is in `android/app/google-services.json`
- Run `flutter clean` and rebuild

### Error: "Missing GoogleService-Info.plist"
- Ensure file is in `ios/Runner/GoogleService-Info.plist`
- Run `flutter clean` and rebuild

### Desktop app: Notes not saving
- Check Firestore Console for errors
- Verify Firestore rules allow write access
- Check network connection

### Mobile app: Notes not saving
- Check Realtime Database Console for errors
- Verify Realtime Database rules allow write access
- Check network connection

---

## Security Notes

⚠️ **Important:** The rules shown above (`allow read, write: if true`) are for **development only**. 

For production, implement proper security rules:
- Use Firebase Authentication
- Restrict access based on user roles
- Validate data structure
- Set up proper indexes

---

## Next Steps

After configuration:
1. Test both apps can save notes to Firebase
2. Verify data appears in Firebase Console
3. Test offline functionality (mobile app)
4. Plan data migration from SQLite to Firebase
5. Set up proper security rules for production

---

## Quick Reference: Finding Configuration Values

**All values can be found in:**
- Firebase Console → Project Settings → General
- Scroll to "Your apps" section
- Click on each app to see configuration

**Database URLs:**
- Firestore: Not needed in config (auto-detected)
- Realtime Database: Found in Realtime Database section → Data tab → URL shown at top

**Project ID:**
- Found in Project Settings → General → Project ID

**Storage Bucket:**
- Found in Project Settings → General → Storage → Default bucket

