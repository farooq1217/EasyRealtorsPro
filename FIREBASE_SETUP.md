# Firebase Setup Guide

## Prerequisites
1. Firebase project created at https://console.firebase.google.com/
2. FlutterFire CLI installed (already done)

## Step 1: Login to Firebase
```bash
firebase login
```

## Step 2: Configure Desktop Admin App
```bash
cd packages/desktop_admin
flutterfire configure
```
- Select your Firebase project
- Select platforms: Windows, Web (and others you need)
- This will automatically update `lib/firebase_options.dart`

## Step 3: Configure Mobile Admin App
```bash
cd ../mobile_admin
flutterfire configure
```
- Select your Firebase project
- Select platforms: Android, iOS (and others you need)
- This will automatically update `lib/firebase_options.dart`

## Step 4: Enable Realtime Database
1. Go to Firebase Console → Realtime Database
2. Click "Create Database"
3. Choose location (closest to your users)
4. Start in **test mode** for now
5. Copy the Database URL (e.g., `https://your-project-default-rtdb.firebaseio.com`)

## Step 5: Set Database Rules
In Firebase Console → Realtime Database → Rules, set:

```json
{
  "rules": {
    ".read": "auth != null",
    ".write": "auth != null"
  }
}
```

**OR for development/testing (less secure):**
```json
{
  "rules": {
    ".read": true,
    ".write": true
  }
}
```

## Step 6: Verify Configuration
Check that `firebase_options.dart` files have real values (not "TODO" placeholders):
- `apiKey`: Should be a real API key
- `appId`: Should be a real app ID (format: `1:123456789:platform:abc123`)
- `projectId`: Your Firebase project ID
- `databaseURL`: Your Realtime Database URL
- `messagingSenderId`: Your sender ID

## Step 7: Test Connection
Run your apps and check:
- Desktop: Agent Working → Office Work / Other Work (should save notes to Firebase)
- Mobile: Same features should work

## Manual Setup (Alternative)
If `flutterfire configure` doesn't work, you can manually get config values:

### For Desktop Admin (Windows):
1. Firebase Console → Project Settings → General
2. Scroll to "Your apps" → Add app → Windows
3. Register app and download `google-services.json` (not used for Flutter, but shows config)
4. Copy values from the config snippet:
   - `apiKey`
   - `appId` 
   - `projectId`
   - `messagingSenderId`
   - `databaseURL` (from Realtime Database section)

### For Mobile Admin (Android):
1. Firebase Console → Project Settings → General
2. Scroll to "Your apps" → Add app → Android
3. Enter package name (check `android/app/build.gradle` for `applicationId`)
4. Download `google-services.json` to `android/app/`
5. Copy config values

### For Mobile Admin (iOS):
1. Firebase Console → Project Settings → General
2. Scroll to "Your apps" → Add app → iOS
3. Enter bundle ID (check `ios/Runner.xcodeproj` or `ios/Runner/Info.plist`)
4. Download `GoogleService-Info.plist` to `ios/Runner/`
5. Copy config values

## Current Firebase Usage in App
The app uses Firebase Realtime Database for:
- **Agent Working Module:**
  - Office Work notes: `agent_working/office_notes`
  - Other Work notes: `agent_working/other_notes`
- **Future sync:** All SQLite data will sync to Firebase

## Troubleshooting
- **"Firebase not initialized"**: Check that `firebase_options.dart` has real values
- **"Permission denied"**: Check Realtime Database rules
- **Connection errors**: Verify `databaseURL` is correct
- **Windows not supported**: Firebase Realtime Database has limited Windows support; consider using Firestore or web API

