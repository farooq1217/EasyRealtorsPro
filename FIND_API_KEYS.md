# How to Find API Keys in Firebase Console

## Project ID: `real-estate-application-agent` ✅

---

## Step-by-Step: Finding API Keys

### For Android App (`com.example.app`):

1. **Go to Firebase Console**: https://console.firebase.google.com/
2. **Select your project**: "Real-estate Application Agent"
3. **Click**: Project Settings (gear icon) → **General** tab
4. **Scroll down** to **"Your apps"** section
5. **Click on the Android app** (`com.example.app`) in the left sidebar
6. **Look for**: In the right panel, you'll see configuration details
7. **Find**: Look for a section showing Firebase configuration
8. **Copy the `apiKey`** - it starts with `AIza...`

   **OR** if you see a code block with Firebase config, look for:
   ```json
   {
     "apiKey": "AIzaSyC...",
     ...
   }
   ```

---

### For iOS App (`real-estate-application-agent`):

1. **Same location**: Project Settings → General → "Your apps"
2. **Click on the iOS app** (`real-estate-application-agent`) in the left sidebar
3. **Look for**: Configuration details in the right panel
4. **Find**: `apiKey` value (starts with `AIza...`)

   **OR** if you downloaded `GoogleService-Info.plist`, open it and find:
   ```xml
   <key>API_KEY</key>
   <string>AIzaSyC...</string>
   ```

---

### For Web App (`Web select karo`):

1. **Same location**: Project Settings → General → "Your apps"
2. **Click on the Web app** (`Web select karo`) in the left sidebar
3. **Look at the right panel**: You'll see "SDK setup and configuration"
4. **Find the radio buttons**: `npm`, `CDN`, `Config`
5. **Click on `Config`** radio button
6. **You'll see a code block** with Firebase configuration:
   ```javascript
   const firebaseConfig = {
     apiKey: "AIzaSyC...",
     authDomain: "...",
     projectId: "...",
     ...
   };
   ```
7. **Copy the `apiKey`** value (the one in quotes after `apiKey:`)

---

### For Windows App (After Adding):

1. **Add Windows App**:
   - In "Your apps" section, click **"Add app"** (blue button, top right)
   - Select **Windows** icon
   - App nickname: `Desktop Admin`
   - Click **"Register app"**

2. **After registration**, Firebase will show you the configuration
3. **Copy these values**:
   - `apiKey` (starts with `AIza...`)
   - `appId` (format: `1:714453411024:windows:xxxxx`)
   - `messagingSenderId` (should be `714453411024`)
   - `projectId` (should be `real-estate-application-agent`)
   - `storageBucket` (format: `real-estate-application-agent.appspot.com`)

---

## Visual Guide:

### Where to Look:

```
Firebase Console
├── Project Settings (gear icon)
    └── General tab
        └── Scroll down to "Your apps"
            ├── Android apps
            │   └── com.example.app ← Click here
            │       └── Right panel shows config
            │           └── Find: apiKey
            │
            ├── Apple apps
            │   └── real-estate-application-agent ← Click here
            │       └── Right panel shows config
            │           └── Find: apiKey
            │
            ├── Web apps
            │   └── Web select karo ← Click here
            │       └── Right panel: Click "Config" tab
            │           └── Find: apiKey in code block
            │
            └── [Add Windows app here]
                └── After adding, copy all config values
```

---

## What Each API Key Looks Like:

- **Format**: `AIzaSyC` followed by ~35 characters
- **Example**: `AIzaSyC1234567890abcdefghijklmnopqrstuvwxyz`
- **Length**: Usually 39 characters total

---

## Quick Checklist:

- [ ] Android API Key: `_________________`
- [ ] iOS API Key: `_________________`
- [ ] Web API Key: `_________________`
- [ ] Windows API Key: `_________________` (after adding Windows app)
- [ ] Windows App ID: `_________________` (after adding Windows app)

---

## After You Have All Values:

Share them with me and I'll update the configuration files automatically!

Or you can:
1. Edit `packages/desktop_admin/firebase_config_template.json`
2. Fill in the values
3. Run: `dart run apply_firebase_config.dart`

