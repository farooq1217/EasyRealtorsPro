# Extract API Key from Downloaded Config Files

## Step 1: Download Config Files

### For Android:
1. Firebase Console → Android app (`com.example.app`)
2. Click **"google-services.json"** download link
3. Save the file

### For iOS:
1. Firebase Console → iOS app (`real-estate-application-agent`)
2. Click **"GoogleService-Info.plist"** download link
3. Save the file

---

## Step 2: Extract API Key

### From google-services.json (Android):

1. Open `google-services.json` in a text editor (Notepad, VS Code, etc.)
2. Look for this structure:
   ```json
   {
     "project_info": {
       "project_id": "real-estate-application-agent",
       "project_number": "714453411024",
       ...
     },
     "client": [
       {
         "client_info": {
           "android_client_info": {
             "package_name": "com.example.app"
           }
         },
         "api_key": [
           {
             "current_key": "AIzaSyC..."  ← THIS IS THE API KEY!
           }
         ],
         ...
       }
     ]
   }
   ```
3. Copy the value of `"current_key"` - that's your Android API Key!

### From GoogleService-Info.plist (iOS):

1. Open `GoogleService-Info.plist` in a text editor
2. Look for:
   ```xml
   <key>API_KEY</key>
   <string>AIzaSyC...</string>  ← THIS IS THE API KEY!
   ```
3. Copy the value between `<string>` tags - that's your iOS API Key!

---

## Step 3: Share the Values

Once you extract the API keys, share them with me and I'll update the configuration files!

---

## Quick Tip:

**The Web API Key (from Config tab) can often be used for Windows/Desktop apps too!**

So if you get the Web API Key, we can use it for Windows configuration as well.

