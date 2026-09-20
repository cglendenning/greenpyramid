import 'package:flutter/material.dart';

import '../services/council_client.dart';
import '../services/db.dart';
import '../services/notification.dart';
import '../services/notification_inbox_service.dart';
import '../theme/app_colors.dart';
import 'batch_checkin_screen.dart';
import 'general_council_screen.dart';
import 'paywall_screen.dart';

/// D-149: the account-scoped notification inbox is available regardless of
/// OS permission or push transport. Items are keyed by the server's stable
/// messageKey, so a foreground/local/push retry cannot create duplicates.
class NotificationInboxScreen extends StatefulWidget {
  const NotificationInboxScreen({super.key});

  @override
  State<NotificationInboxScreen> createState() =>
      _NotificationInboxScreenState();
}

class _NotificationInboxScreenState extends State<NotificationInboxScreen> {
  late final Future<NotificationInboxStream?> _inboxStream;

  @override
  void initState() {
    super.initState();
    _inboxStream = NotificationInboxService.instance.watchInbox();
  }

  Future<void> _open(BuildContext context, Map<String, dynamic> item) async {
    final key = item['messageKey'] as String?;
    if (key != null)
      await CouncilClient.instance
          .markInboxRead(key)
          .catchError((_) => <String, dynamic>{});
    if (!context.mounted) return;
    switch (item['type']) {
      case 'upgrade':
        await Navigator.of(context).push(MaterialPageRoute(settings: const RouteSettings(name: 'PaywallScreen'), 
            builder: (_) => const PaywallScreen(reason: 'notification')));
      case 'batch_checkin':
        final ids = (item['habitIds'] as List<dynamic>? ?? const [])
            .map((id) => id.toString())
            .toSet();
        final tasks = await DatabaseHelper.instance.queryAllTasks();
        final habits = tasks
            .where((task) => ids.contains(task['id']?.toString()))
            .map((task) => <String, dynamic>{
                  'id': task['id']?.toString() ?? '',
                  'category': task['category'],
                  'description': task['taskdescription'],
                  'scheduledtime': task['scheduledtime'],
                })
            .toList();
        if (habits.isNotEmpty) {
          final date =
              DateTime.tryParse(item['occurrenceDate'] as String? ?? '');
          await Navigator.of(context).push(MaterialPageRoute(settings: const RouteSettings(name: 'BatchCheckinScreen'), 
              builder: (_) => BatchCheckinScreen(
                    habits: habits,
                    occurrenceDate: date,
                  )));
        }
        break;
      case 'tailored':
        LocalNotificationService().onNotificationClick.add('/');
        break;
      case 'intervention':
        // D-149/D-152: the inbox item is the rendered engine result. The
        // surface is metadata for the destination; opening it never selects
        // a new policy.
        if (item['surface'] == 'council') {
          await Navigator.of(context).push(MaterialPageRoute(settings: const RouteSettings(name: 'GeneralCouncilScreen'), 
              builder: (_) => GeneralCouncilScreen(
                    notificationMessageKey: key,
                    notificationTitle: item['title'] as String?,
                    notificationBody: item['body'] as String?,
                  )));
        } else {
          LocalNotificationService().onNotificationClick.add('/');
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification inbox')),
      body: FutureBuilder<NotificationInboxStream?>(
        future: _inboxStream,
        builder: (context, streamSnapshot) {
          if (streamSnapshot.hasError) {
            return const Center(
                child: Text('Notifications are temporarily unavailable.'));
          }
          if (!streamSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final stream = streamSnapshot.data;
          if (stream == null) {
            return const Center(child: Text('Sign in to view notifications.'));
          }
          return StreamBuilder<NotificationInboxSnapshot>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                    child: Text('Notifications are temporarily unavailable.'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Center(child: Text('No notifications yet.'));
              }
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final item = docs[index].data();
                  final unread = item['read'] != true;
                  return ListTile(
                    leading: Icon(
                        unread
                            ? Icons.notifications_active
                            : Icons.notifications_none,
                        color: unread ? AppColors.brandGreen : null),
                    title: Text(item['title'] as String? ?? 'Green Pyramid'),
                    subtitle: Text(item['body'] as String? ?? ''),
                    onTap: () => _open(context, item),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
