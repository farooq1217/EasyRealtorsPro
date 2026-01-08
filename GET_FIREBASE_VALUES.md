# Get Firebase Configuration Values - Step by Step

## What I Found from Your Firebase Console:

✅ **Project Number**: `714453411024`  
✅ **Android App ID**: `1:714453411024:android:89ed76a5994e14e32e2ad5`  
✅ **iOS App ID**: `1:714453411024:ios:363090a24fb449542e2ad5`  
✅ **Web App ID**: `1:714453411024:web:91bce9ddb01726c42e2ad5`  

## What We Need:

### 1. Project ID
- Go to Firebase Console → Project Settings → General
- Look for **"Project ID"** (should be something like `real-estate-application-agent`)

### 2. API Keys
For each app, we need the **API Key**:

#### Android App (`com.example.app`):
1. Click on the Android app in the left sidebar
2. Look for **"apiKey"** in the configuration
3. Copy it (starts with "AIza...")

#### iOS App (`real-estate-application-agent`):
1. Click on the iOS app in the left sidebar  
2. Look for **"apiKey"** in the configuration
3. Copy it

#### Web App (`Web select karo`):
1. Click on the Web app in the left sidebar
2. In the "Config" tab, find the Firebase config object
3. Copy the **"apiKey"** value

### 3. Windows App (Need to Add)
1. In Firebase Console → Project Settings → General → "Your apps"
2. Click **"Add app"** button (blue button in top right)
3. Select **Windows** icon
4. Register the app:
   - App nickname: `Desktop Admin`
   - Click **"Register app"**
5. Copy the configuration values shown:
   - `apiKey`
   - `appId` (will be like `1:714453411024:windows:xxxxx`)
   - `messagingSenderId` (same as project number: `714453411024`)
   - `projectId`
   - `storageBucket`

## Quick Checklist:

- [ ] Project ID: `_________________`
- [ ] Android API Key: `_________________`
- [ ] iOS API Key: `_________________`
- [ ] Web API Key: `_________________`
- [ ] Windows API Key: `_________________` (after adding Windows app)
- [ ] Windows App ID: `_________________` (after adding Windows app)

## After Getting Values:

Once you have these values, I'll update the configuration files automatically!

