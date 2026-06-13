import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/todo/view_models/todo_view_model.dart';
import 'package:shared/shared.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Using DefaultTabController for Unread and Read tabs
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          bottom: TabBar(
            indicatorColor: const Color(0xFFFF7F50), // Coral accent
            labelColor: const Color(0xFFFF7F50),
            unselectedLabelColor: Colors.white,
            tabs: const [
              Tab(text: 'Unread'),
              Tab(text: 'Read'),
            ],
          ),
          backgroundColor: Theme.of(context).primaryColor,
        ),
        body: Consumer<TodoViewModel>(
          builder: (context, todoVM, _) {
            final unread = todoVM.unreadReminders;
            final read = todoVM.readReminders;
            return TabBarView(
              children: [
                // Unread tab
                ListView.builder(
                  itemCount: unread.length,
                  itemBuilder: (context, index) {
                    final reminder = unread[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        title: Text(reminder.reminderTitle),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (reminder.reminderDetails != null && reminder.reminderDetails!.isNotEmpty)
                              Text(reminder.reminderDetails!),
                            Text('${reminder.reminderDate} ${reminder.reminderTime}'),
                          ],
                        ),
                        trailing: TextButton(
                          onPressed: () async {
                            await todoVM.markAsRead(reminder.reminderId);
                          },
                          child: const Text(
                            'Mark read',
                            style: TextStyle(color: Color(0xFFFF7F50)), // Coral text
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // Read tab
                ListView.builder(
                  itemCount: read.length,
                  itemBuilder: (context, index) {
                    final reminder = read[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        title: Text(reminder.reminderTitle),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (reminder.reminderDetails != null && reminder.reminderDetails!.isNotEmpty)
                              Text(reminder.reminderDetails!),
                            Text('${reminder.reminderDate} ${reminder.reminderTime}'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
