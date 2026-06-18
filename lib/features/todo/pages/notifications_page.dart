import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_models/todo_view_model.dart';
import 'package:shared/shared.dart';

/// Notifications page with tabs for Unread and Read reminders.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
          appBar: AppBar(
            title: const Text('Notifications'),
            backgroundColor: const Color(0xFF001F54), // Navy accent
            bottom: TabBar(
              indicatorColor: const Color(0xFF001F54), // Navy indicator
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(text: 'Unread'),
                Tab(text: 'Read'),
              ],
            ),
          ),
        body: Consumer<TodoViewModel>(
          builder: (context, todoVM, _) {
            final unread = todoVM.unreadReminders;
            final read = todoVM.readReminders;
            return TabBarView(
              children: [
                _buildList(context, unread, isUnread: true),
                _buildList(context, read, isUnread: false),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<Reminder> reminders,
      {required bool isUnread}) {
    if (reminders.isEmpty) {
      return Center(
        child: Text(isUnread ? 'No unread reminders' : 'No read reminders'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: reminders.length,
      itemBuilder: (context, index) {
        final reminder = reminders[index];
        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.reminderTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${reminder.reminderDate} ${reminder.reminderTime}',
                  style: const TextStyle(color: Colors.grey),
                ),
                if (reminder.reminderDetails != null) ...[
                  const SizedBox(height: 4),
                  Text(reminder.reminderDetails!),
                ],
               if (isUnread) ...[
  const SizedBox(height: 8),
  Align(
    alignment: Alignment.centerRight,
    child: TextButton(
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFFFF6B35),
      ),
      onPressed: () async {
        // ✅ FIXED: Convert int to String
        await Provider.of<TodoViewModel>(context, listen: false)
            .markAsRead(reminder.reminderId.toString());
      },
      child: const Text('Mark read'),
    ),
  ),
],
              ],  
            ),
          ),
        );
      },
    );
  }
}
