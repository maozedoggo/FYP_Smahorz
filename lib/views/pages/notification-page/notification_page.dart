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
    final firestore = FirebaseFirestore.instance;

    // Update invite status in user notifications
    await firestore
        .collection('users')
        .doc(userEmail)
        .collection('notifications')
        .doc(notificationId)
        .update({'status': status});

    if (status == 'accepted') {
      try {
        // ✅ STEP 1: Get inviter’s householdId if not provided
        String? inviterHouseholdId = householdId;
        if (inviterHouseholdId.isEmpty) {
          final inviterDoc = await firestore
              .collection('users')
              .doc(inviterEmail)
              .get();

          if (inviterDoc.exists) {
            final inviterData = inviterDoc.data();
            final inviterHid = inviterData?['householdId'];

            if (inviterHid != null && inviterHid.toString().isNotEmpty) {
              inviterHouseholdId = inviterHid.toString();
            }
          }
        }

        if (inviterHouseholdId.isEmpty) {
          debugPrint("Inviter has no household ID — cannot join household.");
          return;
        }

        // ✅ STEP 2: Update user’s profile with inviter’s householdId & role
        await firestore.collection('users').doc(userEmail).set({
          'householdId': inviterHouseholdId,
          'role': 'member',
        }, SetOptions(merge: true));

        // ✅ STEP 3: Add user as member in household collection
        final householdRef = firestore
            .collection('households')
            .doc(inviterHouseholdId);
        await householdRef.set({
          'members': FieldValue.arrayUnion([userEmail]),
        }, SetOptions(merge: true));

        // ✅ STEP 4: Clean up pending invites
        final pending = await firestore
            .collection('householdInvites')
            .where('toEmail', isEqualTo: userEmail)
            .where('householdId', isEqualTo: inviterHouseholdId)
            .where('status', isEqualTo: 'pending')
            .get();
        for (final doc in pending.docs) {
          await doc.reference.delete();
        }

        // ✅ STEP 5: Notify inviter that invite was accepted
        await firestore
            .collection('users')
            .doc(inviterEmail)
            .collection('notifications')
            .add({
              'fromEmail': userEmail,
              'householdId': inviterHouseholdId,
              'householdName': householdName,
              'type': 'household_response',
              'status': 'accepted',
              'sentAt': FieldValue.serverTimestamp(),
            });
      } catch (e) {
        debugPrint("Error accepting invite: $e");
      }
    } else if (status == 'rejected') {
      // Notify inviter that invite was rejected
      await firestore
          .collection('users')
          .doc(inviterEmail)
          .collection('notifications')
          .add({
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
      return (data['username'] ?? data['name'] ?? data['email'] ?? "Unknown")
          as String;
    } catch (_) {
      return "Unknown";
    }
  }

  Widget _notificationCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade800),
        boxShadow: [
          const BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.35),
            blurRadius: 8,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  String _determineNotificationType(Map<String, dynamic> data) {
    final type = data['type'];
    if (type != null && type.toString().isNotEmpty) return type;
    return 'unknown';
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? "";

    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(
        backgroundColor: const Color(0xFF07101A),
        centerTitle: true,
        title: const Text(
          "Notifications",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(email)
            .collection('notifications')
            .orderBy('sentAt', descending: true)
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
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "No notifications yet.",
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final id = doc.id;

              final type = _determineNotificationType(data);
              final status = data['status'] ?? 'pending';
              final fromEmail = data['fromEmail'] ?? '';
              final householdId = data['householdId'] ?? '';
              final householdName = data['householdName'] ?? '';

              return FutureBuilder<String>(
                future: _getUserDisplayName(fromEmail),
                builder: (context, snap) {
                  final inviter = snap.data ?? "Someone";

                  String title, subtitle;
                  switch (type) {
                    case 'household_invite':
                      title = "Household Invitation";
                      subtitle = "Invite from $inviter to join $householdName";
                      break;
                    case 'household_response':
                      title = "Invite Response";
                      subtitle = "$inviter has $status your invitation.";
                      break;
                    default:
                      title = "Notification";
                      subtitle = "You have a new notification.";
                  }

                  return _notificationCard(
                    child: ListTile(
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
                          (type == 'household_invite' && status == 'pending')
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
