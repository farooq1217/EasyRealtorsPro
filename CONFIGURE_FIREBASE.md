# Quick Firebase Configuration Guide

Since `flutterfire configure` requires interactive input, here's how to manually configure Firebase:

## Step 1: Get Configuration Values from Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project (or create one)
3. Go to **Project Settings** (gear icon) → **General** tab
4. Scroll to **"Your apps"** section

## Step 2: Register Apps (if not done)

### For Desktop Admin (Windows):
1. Click **"Add app"** → Select **Windows** icon
2. Register app → Copy the config values shown

### For Mobile Admin (Android):
1. Click **"Add app"** → Select **Android** icon  
2. Enter package name (check `packages/mobile_admin/android/app/build.gradle` for `applicationId`)
3. Register app → Download `google-services.json` → Save to `packages/mobile_admin/android/app/google-services.json`
4. Copy config values

### For Mobile Admin (iOS):
1. Click **"Add app"** → Select **iOS** icon
2. Enter bundle ID (check `packages/mobile_admin/ios/Runner/Info.plist`)
3. Register app → Download `GoogleService-Info.plist` → Save to `packages/mobile_admin/ios/Runner/GoogleService-Info.plist`
4. Copy config values

## Step 3: Update Desktop Admin Firebase Options

Edit `packages/desktop_admin/lib/firebase_options.dart`:

Replace the Windows configuration:
```dart
static const FirebaseOptions windows = FirebaseOptions(
  apiKey: 'YOUR_ACTUAL_API_KEY',           // From Firebase Console
  appId: '1:123456789:windows:abc123def',  // From Firebase Console
  messagingSenderId: '123456789',          // From Firebase Console
  projectId: 'your-project-id',            // From Firebase Console
  databaseURL: 'https://your-project-default-rtdb.firebaseio.com',  // Optional
  storageBucket: 'your-project-id.appspot.com',  // From Firebase Console
);
```

## Step 4: Update Mobile Admin Firebase Options

Edit `packages/mobile_admin/lib/firebase_options.dart`:

Replace Android configuration:
```dart
static const FirebaseOptions android = FirebaseOptions(
  apiKey: 'YOUR_ACTUAL_API_KEY',
  appId: '1:123456789:android:abc123def',
  messagingSenderId: '123456789',
  projectId: 'your-project-id',
  databaseURL: 'https://your-project-default-rtdb.firebaseio.com',  // From Realtime Database
  storageBucket: 'your-project-id.appspot.com',
);
```

Replace iOS configuration:
```dart
static const FirebaseOptions ios = FirebaseOptions(
  apiKey: 'YOUR_ACTUAL_API_KEY',
  appId: '1:123456789:ios:abc123def',
  messagingSenderId: '123456789',
  projectId: 'your-project-id',
  databaseURL: 'https://your-project-default-rtdb.firebaseio.com',
  storageBucket: 'your-project-id.appspot.com',
  iosBundleId: 'com.example.mobileAdmin',  // Your bundle ID
);
```

## Step 5: Enable Databases

### Firestore (for Desktop):
1. Firebase Console → **Firestore Database** → **Create Database**
2. Start in **test mode**
3. Set location
4. Set rules:
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

### Realtime Database (for Mobile):
1. Firebase Console → **Realtime Database** → **Create Database**
2. Start in **test mode**
3. Set location
4. Set rules:
```json
{
  "rules": {
    ".read": true,
    ".write": true
  }
}
```

## Step 6: Test Configuration

### Desktop App:
```bash
cd packages/desktop_admin
flutter run -d windows
```
- Test: Agent Working → Office Work → Add note
- Check: Firestore Console → `agent_working/office_notes/notes`

### Mobile App:
```bash
cd packages/mobile_admin
flutter run
```
- Test: Add data → Check Realtime Database Console
- Test: Turn off internet → Add data → Turn on internet → Should sync

## Where to Find Values in Firebase Console

All values are in: **Firebase Console → Project Settings → General → Your apps**

- **apiKey**: Shown in config snippet
- **appId**: Format `1:123456789:platform:abc123`
- **messagingSenderId**: Same as project number
- **projectId**: Your project ID
- **databaseURL**: From Realtime Database section (for mobile) or can be constructed
- **storageBucket**: Format `project-id.appspot.com`

