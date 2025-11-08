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
    String userEmail,
    String inviterEmail,
    String householdName,
  ) async {
    final notificationRef = FirebaseFirestore.instance
        .collection('notifications')
        .doc(notificationId);

    // update invite status
    await notificationRef.update({'status': status});

    final firestore = FirebaseFirestore.instance;

    if (status == 'accepted') {
      // add user to household members collection under inviter (optional structure)
      await firestore
          .collection('users')
          .doc(inviterEmail)
          .collection('householdMembers')
          .doc(userEmail)
          .set({'email': userEmail, 'joinedAt': FieldValue.serverTimestamp()});

      // update invited user's profile with householdId
      await firestore.collection('users').doc(userEmail).update({
        'householdId': householdId,
      });

      // notify inviter about acceptance
      await firestore.collection('notifications').add({
        'toEmail': inviterEmail,
        'fromEmail': userEmail,
        'householdId': householdId,
        'householdName': householdName,
        'type': 'household_response',
        'status': 'accepted',
        'sentAt': FieldValue.serverTimestamp(),
      });
    } else if (status == 'rejected') {
      await firestore.collection('notifications').add({
        'toEmail': inviterEmail,
        'fromEmail': userEmail,
        'householdId': householdId,
        'householdName': householdName,
        'type': 'household_response',
        'status': 'rejected',
        'sentAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<String> _getUserDisplayName(String email) async {
    if (email.isEmpty) return "Unknown";
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(email)
          .get();
      final data = doc.data();
      if (data == null) return "Unknown";
      // try common name fields
      return (data['username'] ?? data['name'] ?? data['email'] ?? "Unknown")
          as String;
    } catch (e) {
      return "Unknown";
    }
  }

  Future<void> _markAsRead(String id) async {
    await FirebaseFirestore.instance.collection('notifications').doc(id).update(
      {'status': 'read'},
    );
  }

  Future<void> _deleteNotification(String id) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(id)
        .delete();
  }

  DateTime? _getSentAt(Map<String, dynamic> data, DocumentSnapshot doc) {
    // Accept sentAt, timestamp, createdAt, or use documentCreateTime fallback
    if (data['sentAt'] is Timestamp)
      return (data['sentAt'] as Timestamp).toDate();
    if (data['timestamp'] is Timestamp)
      return (data['timestamp'] as Timestamp).toDate();
    if (data['createdAt'] is Timestamp)
      return (data['createdAt'] as Timestamp).toDate();
    return null;
  }

  // Card widget to match settings page style
  Widget _notificationCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827), // Matches settings page card color
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade800),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 8,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  // Determine notification type based on available fields
  String _determineNotificationType(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type != null && type.isNotEmpty) {
      return type;
    }

    // Auto-detect type based on field presence
    final householdId = data['householdId'] as String?;
    final status = data['status'] as String?;

    if (householdId != null && householdId.isNotEmpty && status == 'pending') {
      return 'household_invite';
    }

    return 'unknown';
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? "";

    // Debug: Print current user email to verify
    print("Current user email: $email");

    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(
        backgroundColor: const Color(0xFF07101A),
        centerTitle: true,
        title: const Text(
          "Notifications",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('toEmail', isEqualTo: email)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print("Stream error: ${snapshot.error}");
            return Center(
              child: Text(
                "Error: ${snapshot.error}",
                style: const TextStyle(color: Colors.white70),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          print("Found ${docs.length} notifications for user $email");

          // Debug: Print all notification documents
          for (final doc in docs) {
            print("Notification doc: ${doc.id} - ${doc.data()}");
          }

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "No notifications yet.",
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          // Convert docs to list of maps + keep original doc for id
          final list = docs.map((d) {
            final m = Map<String, dynamic>.from(
              d.data() as Map<String, dynamic>,
            );
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final item = list[index];
              final id = item['_id'] as String;
              final data = Map<String, dynamic>.from(item);

              print("Building notification: $data");

              final type = _determineNotificationType(data);
              final status = (data['status'] as String?) ?? 'pending';
              final fromEmail = (data['fromEmail'] as String?) ?? '';
              final householdId = (data['householdId'] as String?) ?? '';
              final householdName = (data['householdName'] as String?) ?? '';

              return FutureBuilder<String>(
                future: _getUserDisplayName(fromEmail),
                builder: (context, nameSnap) {
                  final inviter = nameSnap.data ?? "Someone";

                  String title;
                  String subtitle;
                  switch (type) {
                    case 'household_invite':
                      title = "Household Invitation";
                      subtitle = "Invite from $inviter to join $householdName";
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
                      subtitle =
                          data['message']?.toString() ??
                          "You have a new notification.";
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
                      // Capture the messenger early to avoid using a deactivated context later
                      final messenger = ScaffoldMessenger.of(context);

                      if (dir == DismissDirection.startToEnd) {
                        await _markAsRead(id);
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text("Marked as read"),
                            backgroundColor: Colors.green,
                          ),
                        );
                        return false; // don’t remove from the list
                      } else {
                        await _deleteNotification(id);
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text("Deleted"),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                        return true; // allow Dismissible to remove it
                      }
                    },

                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: _notificationCard(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          title: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            subtitle,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          trailing:
                              (type == 'household_invite' &&
                                  status == 'pending')
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextButton(
                                      onPressed: () => respondToInvite(
                                        id,
                                        'accepted',
                                        householdId,
                                        email,
                                        fromEmail,
                                        householdName,
                                      ),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.greenAccent,
                                      ),
                                      child: const Text("Accept"),
                                    ),
                                    TextButton(
                                      onPressed: () => respondToInvite(
                                        id,
                                        'rejected',
                                        householdId,
                                        email,
                                        fromEmail,
                                        householdName,
                                      ),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.redAccent,
                                      ),
                                      child: const Text("Reject"),
                                    ),
                                  ],
                                )
                              : null,
                        ),
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
