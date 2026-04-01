import 'package:flutter/material.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../core/services/update_manager.dart';
import 'package:flutter/foundation.dart';

class UpdateStatusWidget extends StatefulWidget {
  const UpdateStatusWidget({Key? key}) : super(key: key);

  @override
  State<UpdateStatusWidget> createState() => _UpdateStatusWidgetState();
}

class _UpdateStatusWidgetState extends State<UpdateStatusWidget> {
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
      debugPrint('UpdateStatusWidget: Error loading version info: $e');
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
      debugPrint('UpdateStatusWidget: Error checking update status: $e');
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
      
      // Note: If update is successful, the app will close and restart
      // This code may not be reached
    } catch (e) {
      debugPrint('UpdateStatusWidget: Error performing update: $e');
      setState(() {
        _isChecking = false;
      });
      
      if (mounted) {
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
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.system_update,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Application Updates',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Current version info
            Row(
              children: [
                Text('Current Version: '),
                Text(
                  _currentVersion.isNotEmpty ? _currentVersion : 'Loading...',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            
            // Latest version info
            if (_latestVersion.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Text('Latest Version: '),
                  Text(
                    _latestVersion,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
            
            const SizedBox(height: 12),
            
            // Update status and actions
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.new_releases,
                        color: Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Update available!',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _performUpdate,
                      icon: const Icon(Icons.download),
                      label: const Text('Download & Install Update'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'You are using the latest version',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _checkUpdateStatus,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Check for Updates'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
