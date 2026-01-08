# Quick Firebase Setup Guide

## Step 1: Get Your Firebase Configuration Values

### Option A: From Firebase Console (Recommended)

1. **Open Firebase Console**: https://console.firebase.google.com/
2. **Select your project**
3. **Click Project Settings** (gear icon) → **General** tab
4. **Scroll to "Your apps"** section

#### If Windows app doesn't exist:
- Click **"Add app"** → Select **Windows** icon
- App nickname: `Desktop Admin`
- Click **"Register app"**
- Copy the configuration values shown

#### If Windows app exists:
- Click on the Windows app
- View configuration values

### Option B: Using Firebase CLI (If installed)

```bash
firebase use --add
# Select your project
firebase apps:list
```

---

## Step 2: Configure Desktop Admin

### Method 1: Edit Template File (Easiest)

1. **Open**: `packages/desktop_admin/firebase_config_template.json`

2. **Replace placeholder values** with your Firebase values:

```json
{
  "windows": {
    "apiKey": "AIzaSyC...",                    // From Firebase Console
    "appId": "1:123456789:windows:abc123",     // From Firebase Console
    "messagingSenderId": "123456789",          // From Firebase Console
    "projectId": "your-project-id",            // From Firebase Console
    "databaseURL": "https://your-project-default-rtdb.firebaseio.com",
    "storageBucket": "your-project-id.appspot.com"
  }
}
```

3. **Save the file**

4. **Apply configuration**:
```bash
cd packages/desktop_admin
dart run apply_firebase_config.dart
```

### Method 2: Direct Edit

1. **Open**: `packages/desktop_admin/lib/firebase_options.dart`

2. **Find the `windows` configuration** (around line 71)

3. **Replace with your values**:
```dart
static const FirebaseOptions windows = FirebaseOptions(
  apiKey: 'YOUR_API_KEY',
  appId: 'YOUR_APP_ID',
  messagingSenderId: 'YOUR_SENDER_ID',
  projectId: 'YOUR_PROJECT_ID',
  databaseURL: 'https://YOUR_PROJECT_ID-default-rtdb.firebaseio.com',
  storageBucket: 'YOUR_PROJECT_ID.appspot.com',
);
```

---

## Step 3: Enable Firestore Database

1. **Firebase Console** → **Firestore Database**
2. Click **"Create Database"**
3. Choose **"Start in test mode"** (for development)
4. Select location (closest to your users)
5. Click **"Enable"**

### Set Firestore Rules:

1. **Firestore Database** → **Rules** tab
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

## Step 4: Test Configuration

```bash
cd packages/desktop_admin
dart run test_firebase.dart
```

**Expected output:**
```
✅ Configuration looks valid
✅ Firebase initialized successfully!
✅ Firestore connection successful!
```

---

## Step 5: Run the App

```bash
cd packages/desktop_admin
flutter run -d windows
```

---

## What Values to Copy from Firebase Console

When you view your Windows app configuration, you'll see:

```
apiKey: "AIzaSyC1234567890abcdefghijklmnopqrstuvwxyz"
appId: "1:123456789012:windows:abc123def456ghi789"
messagingSenderId: "123456789012"
projectId: "my-firebase-project"
storageBucket: "my-firebase-project.appspot.com"
```

**Copy each value exactly** (you can ignore the quotes in the console, just copy the value itself).

---

## Troubleshooting

### "Configuration still has placeholder values"
- Make sure you replaced ALL placeholder values
- Check for typos
- Verify values are copied correctly (no extra spaces)

### "Firebase not initialized"
- Check that values are correct
- Ensure Firestore Database is created
- Verify rules are set

### "Permission denied"
- Check Firestore rules allow read/write
- Ensure database is in test mode

---

## Next: Configure Mobile Admin

After desktop is configured, configure mobile:

1. **Get Android & iOS config** from Firebase Console
2. **Download** `google-services.json` → Save to `android/app/`
3. **Download** `GoogleService-Info.plist` → Save to `ios/Runner/`
4. **Edit** `packages/mobile_admin/lib/firebase_options.dart`
5. **Enable Realtime Database** in Firebase Console

See `FIREBASE_CONFIGURATION_STEPS.md` for detailed mobile setup.
