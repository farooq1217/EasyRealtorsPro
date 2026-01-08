# Configure Firebase Now - Step by Step

## Quick Configuration Guide

I've created helper scripts to make configuration easier. Follow these steps:

## Option 1: Use Configuration Scripts (Easiest)

### For Desktop Admin:

1. **Get Firebase Values**:
   - Go to https://console.firebase.google.com/
   - Select your project
   - Project Settings → General → Your apps
   - Add Windows app (if not added)
   - Copy the config values shown

2. **Run Configuration Script**:
   ```bash
   cd packages/desktop_admin
   dart run configure_firebase.dart
   ```
   - Enter values when prompted
   - Script will update `firebase_options.dart` automatically

3. **Enable Firestore**:
   - Firebase Console → Firestore Database → Create Database
   - Start in test mode
   - Set rules: `allow read, write: if true;`

### For Mobile Admin:

1. **Get Firebase Values**:
   - Same Firebase project
   - Add Android app → Copy values
   - Add iOS app → Copy values

2. **Run Configuration Script**:
   ```bash
   cd packages/mobile_admin
   dart run configure_firebase.dart
   ```
   - Enter values when prompted

3. **Download Config Files**:
   - Download `google-services.json` → Save to `android/app/`
   - Download `GoogleService-Info.plist` → Save to `ios/Runner/`

4. **Enable Realtime Database**:
   - Firebase Console → Realtime Database → Create Database
   - Start in test mode
   - Set rules: `{ ".read": true, ".write": true }`

## Option 2: Manual Configuration

If scripts don't work, manually edit the files:

### Desktop Admin (`packages/desktop_admin/lib/firebase_options.dart`)

Find and replace the `windows` configuration:

```dart
static const FirebaseOptions windows = FirebaseOptions(
  apiKey: 'YOUR_API_KEY_HERE',           // From Firebase Console
  appId: '1:123456789:windows:abc123',   // From Firebase Console
  messagingSenderId: '123456789',        // From Firebase Console
  projectId: 'your-project-id',          // From Firebase Console
  databaseURL: 'https://your-project-default-rtdb.firebaseio.com',  // Optional
  storageBucket: 'your-project-id.appspot.com',  // From Firebase Console
);
```

### Mobile Admin (`packages/mobile_admin/lib/firebase_options.dart`)

Find and replace `android` and `ios` configurations similarly.

## Where to Find Values

**Firebase Console → Project Settings → General → Your apps**

Each app shows:
- `apiKey`
- `appId` (format: `1:project-number:platform:app-id`)
- `messagingSenderId` (same as project number)
- `projectId`
- `storageBucket` (format: `project-id.appspot.com`)

**Realtime Database URL**:
- Firebase Console → Realtime Database → Data tab
- URL shown at top (format: `https://project-id-default-rtdb.firebaseio.com`)

## After Configuration

### Test Configuration:
```bash
# Desktop
cd packages/desktop_admin
dart run test_firebase.dart

# Mobile
cd packages/mobile_admin
dart run test_firebase.dart
```

### Run Apps:
```bash
# Desktop
cd packages/desktop_admin
flutter run -d windows

# Mobile
cd packages/mobile_admin
flutter run
```

## Verification Checklist

- [ ] `firebase_options.dart` files updated (no "TODO" values)
- [ ] Firestore Database created (Desktop)
- [ ] Realtime Database created (Mobile)
- [ ] Database rules set (test mode)
- [ ] `google-services.json` in `android/app/` (Mobile)
- [ ] `GoogleService-Info.plist` in `ios/Runner/` (Mobile)
- [ ] Test scripts pass
- [ ] Apps run without Firebase errors

## Need Help?

If you're stuck:
1. Run the configuration scripts - they'll guide you step by step
2. Check Firebase Console for any error messages
3. Verify all values are copied correctly (no extra spaces)
4. Ensure databases are created and rules are set

