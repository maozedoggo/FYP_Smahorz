// notification_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  Future<void> respondToInvite(
    String notificationId,
    String status,
    String householdId,
    String userUid,
    String inviterUid,
  ) async {
    final notificationRef =
        FirebaseFirestore.instance.collection('notifications').doc(notificationId);

    // update invite status
    await notificationRef.update({'status': status});

    final firestore = FirebaseFirestore.instance;

    if (status == 'accepted') {
      // add user to household members collection under inviter (optional structure)
      await firestore
          .collection('users')
          .doc(inviterUid)
          .collection('householdMembers')
          .doc(userUid)
          .set({
        'uid': userUid,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      // update invited user's profile with householdId
      await firestore.collection('users').doc(userUid).update({
        'householdId': householdId,
      });

      // notify inviter about acceptance
      await firestore.collection('notifications').add({
        'toUid': inviterUid,
        'fromUid': userUid,
        'householdId': householdId,
        'type': 'household_response',
        'status': 'accepted',
        // keep consistent time field name(s)
        'sentAt': FieldValue.serverTimestamp(),
      });
    } else if (status == 'rejected') {
      await firestore.collection('notifications').add({
        'toUid': inviterUid,
        'fromUid': userUid,
        'householdId': householdId,
        'type': 'household_response',
        'status': 'rejected',
        'sentAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<String> _getUserDisplayName(String uid) async {
    if (uid.isEmpty) return "Unknown";
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data();
      if (data == null) return "Unknown";
      // try common name fields
      return (data['username'] ?? data['name'] ?? data['email'] ?? "Unknown") as String;
    } catch (e) {
      return "Unknown";
    }
  }

  Future<void> _markAsRead(String id) async {
    await FirebaseFirestore.instance.collection('notifications').doc(id).update({'status': 'read'});
  }

  Future<void> _deleteNotification(String id) async {
    await FirebaseFirestore.instance.collection('notifications').doc(id).delete();
  }

  DateTime? _getSentAt(Map<String, dynamic> data, DocumentSnapshot doc) {
    // Accept sentAt, timestamp, createdAt, or use documentCreateTime fallback
    if (data['sentAt'] is Timestamp) return (data['sentAt'] as Timestamp).toDate();
    if (data['timestamp'] is Timestamp) return (data['timestamp'] as Timestamp).toDate();
    if (data['createdAt'] is Timestamp) return (data['createdAt'] as Timestamp).toDate();
    // Firestore DocumentSnapshot has .metadata but not server timestamp; use doc.metadata or serverTimestamp isn't available here.
    // Use server-side document createTime if available (DocumentSnapshot has .metadata.isFromCache, but not createTime in web plugin).
    // As fallback return null.
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Notifications", style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // only filter by toUid — we'll sort locally by sentAt/timestamp if present
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('toUid', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error: ${snapshot.error}",
                style: const TextStyle(color: Colors.white70),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text("No notifications yet.", style: TextStyle(color: Colors.white70)));
          }

          // Convert docs to list of maps + keep original doc for id
          final list = docs.map((d) {
            final m = Map<String, dynamic>.from(d.data() as Map<String, dynamic>);
            m['_id'] = d.id;
            m['_doc'] = d;
            m['_sentAt'] = _getSentAt(m, d);
            return m;
          }).toList();

          // Sort descending by sentAt if present, otherwise keep order received
          list.sort((a, b) {
            final da = a['_sentAt'] as DateTime?;
            final db = b['_sentAt'] as DateTime?;
            if (da == null && db == null) return 0;
            if (da == null) return 1;
            if (db == null) return -1;
            return db.compareTo(da);
          });

          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              final item = list[index];
              final id = item['_id'] as String;
              final data = Map<String, dynamic>.from(item);
              final typeRaw = data['type'] as String? ?? '';
              final status = (data['status'] as String?) ?? 'pending';
              final fromUid = (data['fromUid'] as String?) ?? '';
              final householdId = (data['householdId'] as String?) ?? '';
              String type = typeRaw;

              // Auto-detect invite if type missing but householdId exists and status pending
              if (type.isEmpty && householdId.isNotEmpty && status == 'pending') {
                type = 'household_invite';
              }

              return FutureBuilder<String>(
                future: _getUserDisplayName(fromUid),
                builder: (context, nameSnap) {
                  final inviter = nameSnap.data ?? "Someone";

                  String title;
                  String subtitle;
                  switch (type) {
                    case 'household_invite':
                      title = "Household Invitation";
                      subtitle = "Invite from $inviter";
                      break;
                    case 'household_response':
                      title = "Invite Response";
                      subtitle = "$inviter has $status your invitation.";
                      break;
                    case 'vote_started':
                      title = "Vote started";
                      subtitle = "A vote has begun to choose a new admin.";
                      break;
                    case 'vote_result':
                      title = "Vote result";
                      subtitle = "$inviter is now the admin.";
                      break;
                    default:
                      title = "Notification";
                      subtitle = data['message']?.toString() ?? "You have a notification.";
                  }

                  return Dismissible(
                    key: Key(id),
                    background: Container(
                      color: Colors.green.withOpacity(0.7),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Icon(Icons.check, color: Colors.white),
                    ),
                    secondaryBackground: Container(
                      color: Colors.red.withOpacity(0.7),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (dir) async {
                      if (dir == DismissDirection.startToEnd) {
                        await _markAsRead(id);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Marked as read"), backgroundColor: Colors.green));
                        return false;
                      } else {
                        await _deleteNotification(id);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Deleted"), backgroundColor: Colors.redAccent));
                        return true;
                      }
                    },
                    child: Card(
                      color: const Color(0xFF1E1E1E),
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white70)),
                        trailing: (type == 'household_invite' && status == 'pending')
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextButton(
                                      onPressed: () => respondToInvite(id, 'accepted', householdId, uid, fromUid),
                                      child: const Text("Accept", style: TextStyle(color: Colors.greenAccent))),
                                  TextButton(
                                      onPressed: () => respondToInvite(id, 'rejected', householdId, uid, fromUid),
                                      child: const Text("Reject", style: TextStyle(color: Colors.redAccent))),
                                ],
                              )
                            : null,
                      ),
                    ),
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
