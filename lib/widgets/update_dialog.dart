import 'package:flutter/material.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../core/services/update_manager.dart';
import 'package:flutter/foundation.dart';

class UpdateDialog extends StatefulWidget {
  const UpdateDialog({Key? key}) : super(key: key);

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const UpdateDialog(),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  final UpdateManager _updateManager = UpdateManager();
  String _currentVersion = '';
  String _latestVersion = '';
  bool _isChecking = false;
  bool _updateAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
  }

  Future<void> _loadVersionInfo() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _currentVersion = packageInfo.version;
      });
      
      _checkUpdateStatus();
    } catch (e) {
      debugPrint('UpdateDialog: Error loading version info: $e');
    }
  }

  Future<void> _checkUpdateStatus() async {
    setState(() {
      _isChecking = true;
    });

    try {
      String latestVersion = await _updateManager.getLatestVersion();
      bool updateAvailable = await _updateManager.isUpdateAvailable();
      
      setState(() {
        _latestVersion = latestVersion;
        _updateAvailable = updateAvailable;
        _isChecking = false;
      });
    } catch (e) {
      debugPrint('UpdateDialog: Error checking update status: $e');
      setState(() {
        _isChecking = false;
      });
    }
  }

  Future<void> _performUpdate() async {
    try {
      setState(() {
        _isChecking = true;
      });
      
      await _updateManager.checkForUpdate();
      
      // Note: If update is successful, app will close and restart
      // This code may not be reached
    } catch (e) {
      debugPrint('UpdateDialog: Error performing update: $e');
      setState(() {
        _isChecking = false;
      });
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.system_update,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 8),
          const Text('App Updates'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current version info
            Row(
              children: [
                const Text('Current Version: '),
                Text(
                  _currentVersion.isNotEmpty ? _currentVersion : 'Loading...',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            
            // Latest version info
            if (_latestVersion.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Latest Version: '),
                  Text(
                    _latestVersion,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Update status
            if (_isChecking)
              const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Checking for updates...'),
                ],
              )
            else if (_updateAvailable)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.new_releases,
                          color: Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Update Available!',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'A new version is available. Would you like to download and install it now?',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'You are using the latest version',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (_isChecking)
          const SizedBox.shrink()
        else if (_updateAvailable) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
          ElevatedButton.icon(
            onPressed: _performUpdate,
            icon: const Icon(Icons.download),
            label: const Text('Update Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ] else ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          OutlinedButton.icon(
            onPressed: _checkUpdateStatus,
            icon: const Icon(Icons.refresh),
            label: const Text('Check Again'),
          ),
        ],
      ],
    );
  }
}
