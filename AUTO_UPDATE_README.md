# EasyRealtorsPro Auto-Update Mechanism

This document explains the custom auto-update mechanism implemented for the EasyRealtorsPro Windows desktop application.

## Overview

The auto-update system allows the application to automatically check for updates, download them, and install them without requiring manual intervention. This is particularly important for Windows desktop applications where files cannot be replaced while the application is running.

## Architecture

The update mechanism consists of the following components:

### 1. UpdateManager Service (`lib/core/services/update_manager.dart`)

The core service that handles the entire update process:

- **Version Checking**: Fetches latest version from Firebase Remote Config
- **Downloading**: Downloads the update ZIP file using Dio
- **Extraction**: Extracts the ZIP file using the archive package
- **Installation**: Creates and executes a batch script for file replacement

### 2. UpdateStatusWidget (`lib/widgets/update_status_widget.dart`)

A UI widget that displays update information and allows manual update checks:

- Shows current and latest versions
- Displays update availability status
- Provides download/install buttons
- Integrated with your app's UI

### 3. UpdateDialog (`lib/widgets/update_dialog.dart`)

A modal dialog for update management:

- Quick access to update status
- Manual update check functionality
- User-friendly interface for update actions

## Dependencies Added

```yaml
firebase_remote_config: ^6.1.3    # For version management
package_info_plus: ^4.2.0           # For current version info
dio: ^5.4.0                        # For downloading updates
archive: ^3.4.9                     # For ZIP extraction
```

## Update Workflow

### 1. Automatic Check (App Startup)
- When the app starts, `UpdateManager().checkForUpdate()` is called after Firebase initialization
- The system fetches `latest_version` and `update_url` from Firebase Remote Config
- If a newer version is available, the update process begins automatically

### 2. Version Comparison
- Current version is obtained using `package_info_plus`
- Latest version is fetched from Firebase Remote Config
- Version comparison determines if an update is needed

### 3. Download Process
- The update ZIP file is downloaded to the Windows temporary directory
- Progress is logged to the console for debugging

### 4. Extraction
- The ZIP file is extracted to a temporary folder
- All files and directories are preserved with their structure

### 5. Installation via Batch Script
- A batch script (`updater.bat`) is created in the temporary directory
- The script waits 3 seconds for the app to close
- Copies all extracted files to `%LOCALAPPDATA%\EasyRealtorsPro`
- Restarts the application
- Deletes itself after completion

## Firebase Remote Config Setup

### Required Parameters

1. **latest_version** (String)
   - The latest version number of your application
   - Format: "0.1.0", "1.2.3", etc.

2. **update_url** (String)
   - Direct URL to the ZIP file containing the updated application
   - Should be a publicly accessible URL

### Example Firebase Remote Config Setup

```json
{
  "latest_version": "0.2.0",
  "update_url": "https://your-cdn.com/easyrealtorspro-updates/v0.2.0.zip"
}
```

## Update ZIP Structure

The ZIP file should contain the complete application structure:

```
EasyRealtorsPro_Update/
├── easy_realtors_pro.exe
├── data/
│   └── (application data files)
├── assets/
│   └── (application assets)
└── (other application files)
```

## Usage in Your Application

### Automatic Updates
The system is automatically initialized in `main.dart`:

```dart
// In main.dart, after Firebase initialization
if (isWindows) {
  debugPrint('Windows Platform: Checking for updates...');
  UpdateManager().checkForUpdate();
}
```

### Manual Update Check
You can trigger update checks manually:

```dart
// Show update dialog
UpdateDialog.show(context);

// Or check programmatically
final updateManager = UpdateManager();
bool hasUpdate = await updateManager.isUpdateAvailable();
if (hasUpdate) {
  await updateManager.checkForUpdate();
}
```

### Using UpdateStatusWidget
Add the widget to any page to show update status:

```dart
class MyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Your existing content
          UpdateStatusWidget(), // Add this widget
        ],
      ),
    );
  }
}
```

## Security Considerations

### 1. ZIP File Security
- Ensure the update URL is secure (HTTPS)
- Consider implementing digital signature verification
- Validate the ZIP structure before extraction

### 2. Batch Script Security
- The batch script runs with user privileges
- Ensure the extraction path is secure
- Consider adding checksum verification

### 3. Firebase Remote Config
- Use Firebase security rules to control access
- Implement proper authentication for Remote Config
- Consider using Firebase App Check for additional security

## Troubleshooting

### Common Issues

1. **Download Fails**
   - Check internet connectivity
   - Verify the update_url is accessible
   - Check Firebase Remote Config configuration

2. **Extraction Fails**
   - Ensure ZIP file is not corrupted
   - Check file permissions in temporary directory
   - Verify ZIP structure

3. **Installation Fails**
   - Check file permissions in %LOCALAPPDATA%
   - Ensure the app is not running during update
   - Verify batch script execution

### Debug Logging

Enable debug logging to troubleshoot issues:

```dart
// All update operations are logged with debugPrint
// Look for "UpdateManager:" prefix in console logs
```

### Error Handling

The system includes comprehensive error handling:

- Network errors during download
- File system errors during extraction
- Permission errors during installation
- Firebase Remote Config errors

## Best Practices

### 1. Version Management
- Use semantic versioning (major.minor.patch)
- Increment version numbers consistently
- Test updates thoroughly before deployment

### 2. Update Process
- Test the complete update workflow
- Ensure backward compatibility
- Provide rollback mechanisms if needed

### 3. User Experience
- Provide clear feedback during updates
- Allow users to defer updates
- Show update progress and status

### 4. Monitoring
- Monitor update success rates
- Track update failures and reasons
- Implement analytics for update usage

## Testing

### Development Testing
1. Set up Firebase Remote Config with test values
2. Create a test ZIP file with a higher version number
3. Test the complete update workflow
4. Verify batch script execution

### Production Testing
1. Test with real deployment environment
2. Verify update from older versions
3. Test update failure scenarios
4. Validate user experience

## Future Enhancements

### Potential Improvements
1. **Delta Updates**: Only download changed files
2. **Background Updates**: Download updates in background
3. **Rollback Support**: Ability to revert to previous version
4. **Update Scheduling**: Schedule updates for specific times
5. **Multiple Platforms**: Extend to macOS and Linux

### Additional Features
1. **Update Notifications**: Notify users of available updates
2. **Update History**: Track update history
3. **Beta Updates**: Support for beta channel updates
4. **Forced Updates**: Mandatory security updates

## Support

For issues or questions about the auto-update mechanism:

1. Check the console logs for "UpdateManager:" entries
2. Verify Firebase Remote Config configuration
3. Test network connectivity and file permissions
4. Review the troubleshooting section above

---

**Note**: This auto-update mechanism is specifically designed for Windows desktop applications. For other platforms, different approaches may be required.
