import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  /// 🔹 Handle invite responses
  Future<void> respondToInvite(
    String notificationId,
    String status,
    String householdId,
    String userUid,
    String inviterUid,
  ) async {
    final notificationRef =
        FirebaseFirestore.instance.collection('notifications').doc(notificationId);

    // Update notification status
    await notificationRef.update({'status': status});

    if (status == 'accepted') {
      final firestore = FirebaseFirestore.instance;

      // Add user to household's member list
      await firestore
          .collection('users')
          .doc(inviterUid) // inviter is household owner
          .collection('householdMembers')
          .doc(userUid)
          .set({
        'uid': userUid,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      // Update invited user's profile with householdId
      await firestore.collection('users').doc(userUid).update({
        'householdId': householdId,
      });

      // Notify inviter that user accepted
      await firestore.collection('notifications').add({
        'toUid': inviterUid,
        'fromUid': userUid,
        'householdId': householdId,
        'type': 'household_response',
        'status': 'accepted',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } else if (status == 'rejected') {
      // Notify inviter that user rejected
      await FirebaseFirestore.instance.collection('notifications').add({
        'toUid': inviterUid,
        'fromUid': userUid,
        'householdId': householdId,
        'type': 'household_response',
        'status': 'rejected',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text("Notifications")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('toUid', isEqualTo: uid)
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No notifications"));
          }

          return ListView(
            children: snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return Card(
                child: ListTile(
                  title: Text("Invite from ${data['fromUid']}"),
                  subtitle: Text("Household: ${data['householdId']}"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => respondToInvite(
                          doc.id,
                          "accepted",
                          data['householdId'],
                          uid,
                          data['fromUid'],
                        ),
                        child: const Text("Accept"),
                      ),
                      TextButton(
                        onPressed: () => respondToInvite(
                          doc.id,
                          "rejected",
                          data['householdId'],
                          uid,
                          data['fromUid'],
                        ),
                        child: const Text("Reject"),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
