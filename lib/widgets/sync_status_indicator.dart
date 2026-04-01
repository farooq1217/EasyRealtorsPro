import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/services/network_sync_manager.dart';

/// Sync Status Indicator Widget
/// 
/// Displays real-time sync status with visual indicators
/// and provides users with feedback about data synchronization.
class SyncStatusIndicator extends StatelessWidget {
  final SyncStatus status;

  const SyncStatusIndicator({
    Key? key,
    required this.status,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getBorderColor()),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildStatusIcon(),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getStatusTitle(),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _getTextColor(),
                      ),
                    ),
                    if (status.operation != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        status.operation!,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: _getTextColor().withOpacity(0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (status.isSyncing)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(_getTextColor()),
                  ),
                ),
            ],
          ),
          if (status.progress != null) ...[
            const SizedBox(height: 8),
            _buildProgressBar(),
          ],
          if (status.lastSyncTime != null) ...[
            const SizedBox(height: 4),
            Text(
              'Last sync: _formatDateTime(status.lastSyncTime!)',
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: _getTextColor().withOpacity(0.7),
              ),
            ),
          ],
          if (status.pendingOperations != null && status.pendingOperations! > 0) ...[
            const SizedBox(height: 4),
            Text(
              '${status.pendingOperations} pending operations',
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: _getTextColor().withOpacity(0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusIcon() {
    IconData icon;
    if (status.isSyncing) {
      icon = Icons.sync;
    } else if (status.isSynced) {
      icon = Icons.cloud_done;
    } else if (status.isPending) {
      icon = Icons.cloud_queue;
    } else {
      icon = Icons.cloud_off;
    }

    return Icon(
      icon,
      size: 20,
      color: _getTextColor(),
    );
  }

  Widget _buildProgressBar() {
    if (status.progress == null) return const SizedBox.shrink();

    final progress = status.progress!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              progress.currentTable,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: _getTextColor().withOpacity(0.8),
              ),
            ),
            Text(
              '${progress.completedTables}/${progress.totalTables}',
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: _getTextColor().withOpacity(0.8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress.percentage,
          backgroundColor: _getTextColor().withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation<Color>(_getTextColor()),
        ),
      ],
    );
  }

  Color _getBackgroundColor() {
    if (status.isSyncing) {
      return Colors.blue.shade50;
    } else if (status.isSynced) {
      return Colors.green.shade50;
    } else if (status.isPending) {
      return Colors.orange.shade50;
    } else {
      return Colors.grey.shade50;
    }
  }

  Color _getBorderColor() {
    if (status.isSyncing) {
      return Colors.blue.shade200;
    } else if (status.isSynced) {
      return Colors.green.shade200;
    } else if (status.isPending) {
      return Colors.orange.shade200;
    } else {
      return Colors.grey.shade200;
    }
  }

  Color _getTextColor() {
    if (status.isSyncing) {
      return Colors.blue.shade600;
    } else if (status.isSynced) {
      return Colors.green.shade600;
    } else if (status.isPending) {
      return Colors.orange.shade600;
    } else {
      return Colors.grey.shade600;
    }
  }

  String _getStatusTitle() {
    if (status.isSyncing) {
      return 'Syncing...';
    } else if (status.isSynced) {
      return 'Synced';
    } else if (status.isPending) {
      return 'Pending Sync';
    } else {
      return 'Never Synced';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}

/// Compact Sync Status Indicator for use in app bars and headers
class CompactSyncStatusIndicator extends StatelessWidget {
  final SyncStatus status;
  final VoidCallback? onTap;

  const CompactSyncStatusIndicator({
    Key? key,
    required this.status,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _getBackgroundColor(),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _getBorderColor()),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (status.isSyncing)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(_getTextColor()),
                ),
              )
            else
              Icon(
                _getStatusIcon(),
                size: 12,
                color: _getTextColor(),
              ),
            const SizedBox(width: 4),
            Text(
              _getStatusText(),
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: _getTextColor(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon() {
    if (status.isSyncing) {
      return Icons.sync;
    } else if (status.isSynced) {
      return Icons.cloud_done;
    } else if (status.isPending) {
      return Icons.cloud_queue;
    } else {
      return Icons.cloud_off;
    }
  }

  String _getStatusText() {
    if (status.isSyncing) {
      return 'Syncing';
    } else if (status.isSynced) {
      return 'Synced';
    } else if (status.isPending) {
      return 'Pending';
    } else {
      return 'Offline';
    }
  }

  Color _getBackgroundColor() {
    if (status.isSyncing) {
      return Colors.blue.shade50;
    } else if (status.isSynced) {
      return Colors.green.shade50;
    } else if (status.isPending) {
      return Colors.orange.shade50;
    } else {
      return Colors.grey.shade50;
    }
  }

  Color _getBorderColor() {
    if (status.isSyncing) {
      return Colors.blue.shade200;
    } else if (status.isSynced) {
      return Colors.green.shade200;
    } else if (status.isPending) {
      return Colors.orange.shade200;
    } else {
      return Colors.grey.shade200;
    }
  }

  Color _getTextColor() {
    if (status.isSyncing) {
      return Colors.blue.shade600;
    } else if (status.isSynced) {
      return Colors.green.shade600;
    } else if (status.isPending) {
      return Colors.orange.shade600;
    } else {
      return Colors.grey.shade600;
    }
  }
}

/// Sync Status Button with detailed information dialog
class SyncStatusButton extends StatelessWidget {
  final SyncStatus status;
  final VoidCallback? onForceSync;

  const SyncStatusButton({
    Key? key,
    required this.status,
    this.onForceSync,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => _showSyncDetails(context),
      icon: Icon(
        _getStatusIcon(),
        color: _getTextColor(),
      ),
      tooltip: 'Sync Status',
    );
  }

  IconData _getStatusIcon() {
    if (status.isSyncing) {
      return Icons.sync;
    } else if (status.isSynced) {
      return Icons.cloud_done;
    } else if (status.isPending) {
      return Icons.cloud_queue;
    } else {
      return Icons.cloud_off;
    }
  }

  Color _getTextColor() {
    if (status.isSyncing) {
      return Colors.blue.shade600;
    } else if (status.isSynced) {
      return Colors.green.shade600;
    } else if (status.isPending) {
      return Colors.orange.shade600;
    } else {
      return Colors.grey.shade600;
    }
  }

  void _showSyncDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(_getStatusIcon(), color: _getTextColor()),
            const SizedBox(width: 8),
            Text(
              'Sync Status',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusRow('Status', _getStatusTitle()),
              if (status.operation != null)
                _buildStatusRow('Operation', status.operation!),
              if (status.lastSyncTime != null)
                _buildStatusRow('Last Sync', _formatDateTime(status.lastSyncTime!)),
              if (status.pendingOperations != null)
                _buildStatusRow('Pending Operations', status.pendingOperations.toString()),
              if (status.progress != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Progress',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: status.progress!.percentage,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(_getTextColor()),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      status.progress!.currentTable,
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                    Text(
                      '${status.progress!.completedTables}/${status.progress!.totalTables}',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (!status.isSyncing && onForceSync != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onForceSync!();
              },
              child: Text(
                'Force Sync',
                style: GoogleFonts.poppins(color: const Color(0xFFFF6B35)),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Close',
              style: GoogleFonts.poppins(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusTitle() {
    if (status.isSyncing) {
      return 'Syncing...';
    } else if (status.isSynced) {
      return 'Synced';
    } else if (status.isPending) {
      return 'Pending Sync';
    } else {
      return 'Never Synced';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
