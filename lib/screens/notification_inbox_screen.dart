import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/council_client.dart';
import '../theme/app_colors.dart';
import 'batch_checkin_screen.dart';
import 'paywall_screen.dart';

/// D-149: the account-scoped notification inbox is available regardless of
/// OS permission or push transport. Items are keyed by the server's stable
/// messageKey, so a foreground/local/push retry cannot create duplicates.
class NotificationInboxScreen extends StatelessWidget {
  const NotificationInboxScreen({super.key});

  CollectionReference<Map<String, dynamic>>? get _inbox {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid).collection('inbox');
  }

  Future<void> _open(BuildContext context, Map<String, dynamic> item) async {
    final key = item['messageKey'] as String?;
    if (key != null) await CouncilClient.instance.markInboxRead(key).catchError((_) => <String, dynamic>{});
    if (!context.mounted) return;
    switch (item['type']) {
      case 'upgrade':
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaywallScreen(reason: 'notification')));
      case 'batch_checkin':
        final habits = (item['habits'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>().toList();
        if (habits.isNotEmpty) {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => BatchCheckinScreen(habits: habits)));
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inbox = _inbox;
    if (inbox == null) return const Scaffold(body: Center(child: Text('Sign in to view notifications.')));
    return Scaffold(
      appBar: AppBar(title: const Text('Notification inbox')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: inbox.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Notifications are temporarily unavailable.'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No notifications yet.'));
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final item = docs[index].data();
              final unread = item['read'] != true;
              return ListTile(
                leading: Icon(unread ? Icons.notifications_active : Icons.notifications_none,
                    color: unread ? AppColors.brandGreen : null),
                title: Text(item['title'] as String? ?? 'Green Pyramid'),
                subtitle: Text(item['body'] as String? ?? ''),
                onTap: () => _open(context, item),
              );
            },
          );
        },
      ),
    );
  }
}
