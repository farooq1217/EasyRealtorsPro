# Alternative Ways to Find API Key

## If API Key is Not Visible in App Configuration:

### Method 1: Check Downloaded Config Files

#### For Android:
1. In Firebase Console → Android app → Click **"google-services.json"** download link
2. Download the file
3. Open `google-services.json` in a text editor
4. Look for:
   ```json
   {
     "project_info": {
       "project_id": "...",
       "project_number": "...",
       ...
     },
     "client": [{
       "api_key": [{
         "current_key": "AIzaSyC..."  ← THIS is the API Key!
       }]
     }]
   }
   ```

#### For iOS:
1. In Firebase Console → iOS app → Click **"GoogleService-Info.plist"** download link
2. Download the file
3. Open `GoogleService-Info.plist` in a text editor
4. Look for:
   ```xml
   <key>API_KEY</key>
   <string>AIzaSyC...</string>  ← THIS is the API Key!
   ```

### Method 2: Check Web App Config Code

1. Click on **Web app** (`Web select karo`)
2. Click the **"Config"** radio button (not npm or CDN)
3. You'll see a code block like:
   ```javascript
   const firebaseConfig = {
     apiKey: "AIzaSyC...",  ← Copy this!
     authDomain: "...",
     projectId: "...",
     ...
   };
   ```
4. The `apiKey` value here can often be used for other platforms too!

### Method 3: Check Project Settings → Cloud Messaging

1. Firebase Console → Project Settings
2. Go to **"Cloud Messaging"** tab
3. Look for **"Server key"** or **"API Key"** - sometimes it's here

### Method 4: Use Web API Key for All Platforms

**Good News**: Often, the **Web API Key** can be used for Windows/Desktop apps too!

1. Get the Web API Key from the Config tab (Method 2)
2. We can use that same key for Windows configuration

---

## Quick Action:

**Try this first:**
1. Click on **Web app** (`Web select karo`)
2. Click **"Config"** radio button
3. Copy the `apiKey` value from the code block
4. Share it with me - we can use it for Windows too!

---

## What to Look For:

The API key will look like one of these:
- `AIzaSyC1234567890abcdefghijklmnopqrstuvwxyz`
- `AIzaSyD...` (different letter after AIza)
- `AIza...` (always starts with AIza)

It's usually 39 characters long.

