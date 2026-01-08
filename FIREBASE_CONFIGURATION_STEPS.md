# Firebase Configuration - Complete Steps

## Quick Start (Choose One Method)

### Method 1: Interactive Script (Recommended)
```bash
cd packages/desktop_admin
dart run configure_firebase.dart
```
Follow the prompts and enter values from Firebase Console.

### Method 2: Template File
1. Edit `packages/desktop_admin/firebase_config_template.json`
2. Fill in your Firebase values
3. Run: `dart run apply_firebase_config.dart`

### Method 3: Manual Edit
Directly edit `packages/desktop_admin/lib/firebase_options.dart`

---

## Step-by-Step: Get Firebase Values

### Step 1: Go to Firebase Console
1. Open https://console.firebase.google.com/
2. Sign in with your Google account
3. Select your project (or create new one)

### Step 2: Get Windows App Configuration
1. Click **Project Settings** (gear icon) → **General** tab
2. Scroll to **"Your apps"** section
3. If Windows app doesn't exist:
   - Click **"Add app"** → Select **Windows** icon
   - Register app → Copy the config values shown
4. If Windows app exists:
   - Click on it → View configuration

**Copy these values:**
- `apiKey` (starts with "AIza...")
- `appId` (format: `1:123456789:windows:abc123def456`)
- `messagingSenderId` (number, same as project number)
- `projectId` (your project ID)
- `storageBucket` (format: `project-id.appspot.com`)

### Step 3: Get Web App Configuration (Optional)
1. Same Firebase Console → Project Settings
2. Click **"Add app"** → Select **Web** icon (`</>`)
3. Register app → Copy config values
4. Copy: `apiKey`, `appId`, `authDomain`, `measurementId`

### Step 4: Enable Firestore Database
1. Firebase Console → **Firestore Database**
2. Click **"Create Database"**
3. Choose **"Start in test mode"**
4. Select location (closest to your users)
5. Click **"Enable"**

### Step 5: Set Firestore Rules
1. Firestore Database → **Rules** tab
2. Replace with:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```
3. Click **"Publish"**

---

## Configuration Methods

### Method 1: Interactive Script

Run:
```bash
cd packages/desktop_admin
dart run configure_firebase.dart
```

The script will prompt for each value. Enter values from Firebase Console.

### Method 2: Template File

1. **Edit the template**:
   ```bash
   # Open firebase_config_template.json in your editor
   # Replace placeholder values with real Firebase values
   ```

2. **Apply configuration**:
   ```bash
   dart run apply_firebase_config.dart
   ```

### Method 3: Direct Edit

Edit `lib/firebase_options.dart` directly:

Find:
```dart
static const FirebaseOptions windows = FirebaseOptions(
  apiKey: 'TODO_WINDOWS_API_KEY',
  appId: '1:000000000000:windows:placeholder',
  ...
);
```

Replace with:
```dart
static const FirebaseOptions windows = FirebaseOptions(
  apiKey: 'AIzaSyC...',  // Your actual API key
  appId: '1:123456789:windows:abc123',  // Your actual app ID
  messagingSenderId: '123456789',  // Your sender ID
  projectId: 'your-actual-project-id',  // Your project ID
  databaseURL: 'https://your-project-default-rtdb.firebaseio.com',
  storageBucket: 'your-project-id.appspot.com',
);
```

---

## Mobile Admin Configuration

### Step 1: Get Android Configuration
1. Firebase Console → Project Settings → Your apps
2. Add Android app (if not exists)
3. Enter package name (check `android/app/build.gradle` for `applicationId`)
4. Download `google-services.json` → Save to `android/app/google-services.json`
5. Copy config values

### Step 2: Get iOS Configuration
1. Add iOS app in Firebase Console
2. Enter bundle ID (check `ios/Runner/Info.plist`)
3. Download `GoogleService-Info.plist` → Save to `ios/Runner/GoogleService-Info.plist`
4. Copy config values

### Step 3: Configure Mobile
```bash
cd packages/mobile_admin
dart run configure_firebase.dart
```

Or manually edit `lib/firebase_options.dart`

### Step 4: Enable Realtime Database
1. Firebase Console → **Realtime Database**
2. Click **"Create Database"**
3. Start in **test mode**
4. Set rules:
```json
{
  "rules": {
    ".read": true,
    ".write": true
  }
}
```

---

## Verification

### Test Desktop Configuration:
```bash
cd packages/desktop_admin
dart run test_firebase.dart
```

**Expected output if configured:**
```
✅ Configuration looks valid (no placeholders found)
✅ Firebase initialized successfully!
✅ Firestore connection successful!
```

### Test Mobile Configuration:
```bash
cd packages/mobile_admin
dart run test_firebase.dart
```

---

## Troubleshooting

### "Configuration still has placeholder values"
- Check `firebase_options.dart` - make sure all "TODO" values are replaced
- Verify values are copied correctly (no extra spaces)

### "Firebase not initialized"
- Check that `Firebase.initializeApp()` is called in `main()`
- Verify configuration values are correct

### "Permission denied"
- Check Firestore/Realtime Database rules
- Ensure rules allow read/write (for development)

### "Database not found"
- Ensure Firestore/Realtime Database is created in Firebase Console
- Check database URL is correct

---

## After Configuration

1. ✅ Run test scripts to verify
2. ✅ Run apps and test Firebase features
3. ✅ Check Firebase Console to see data appearing
4. ✅ Test offline functionality (mobile app)

---

## Quick Reference

**Firebase Console**: https://console.firebase.google.com/

**Config Files**:
- Desktop: `packages/desktop_admin/lib/firebase_options.dart`
- Mobile: `packages/mobile_admin/lib/firebase_options.dart`

**Test Scripts**:
- Desktop: `packages/desktop_admin/test_firebase.dart`
- Mobile: `packages/mobile_admin/test_firebase.dart`

**Config Scripts**:
- Desktop: `packages/desktop_admin/configure_firebase.dart`
- Mobile: `packages/mobile_admin/configure_firebase.dart`

