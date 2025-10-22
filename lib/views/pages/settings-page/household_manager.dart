import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HouseholdManager extends StatefulWidget {
  const HouseholdManager({Key? key}) : super(key: key);

  @override
  State<HouseholdManager> createState() => _HouseholdManagerState();
}

class _HouseholdManagerState extends State<HouseholdManager> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  String? _householdId;
  bool _isAdmin = false;
  String _householdName = "Unnamed Household";
  List<Map<String, dynamic>> _members = [];

  @override
  void initState() {
    super.initState();
    _loadHouseholdData();
  }

  Future<void> _loadHouseholdData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      if (userData == null) return;

      final householdId = userData['householdId'];
      final isAdmin = userData['isAdmin'] ?? false;

      if (householdId == null || householdId.isEmpty) {
        setState(() {
          _householdId = null;
          _isAdmin = false;
          _isLoading = false;
        });
        return;
      }

      final householdDoc =
          await _firestore.collection('households').doc(householdId).get();

      if (householdDoc.exists) {
        final data = householdDoc.data() ?? {};
        final memberIds = List<String>.from(data['members'] ?? []);
        final membersData = await Future.wait(memberIds.map((id) async {
          final doc = await _firestore.collection('users').doc(id).get();
          final d = doc.data() ?? {};
          return {
            'id': id,
            'name': d['name'] ?? 'Unknown',
            'email': d['email'] ?? 'No email',
          };
        }));

        setState(() {
          _householdId = householdId;
          _householdName = data['name'] ?? 'Unnamed Household';
          _isAdmin = isAdmin;
          _members = membersData;
          _isLoading = false;
        });
      } else {
        setState(() {
          _householdId = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading household: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createHousehold() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Create Household"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Household Name"),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final name = controller.text.trim().isEmpty
                  ? "Unnamed Household"
                  : controller.text.trim();

              // Create household doc
              final newHousehold =
                  await _firestore.collection('households').add({
                'name': name,
                'adminId': user.uid,
                'members': [user.uid],
              });

              // Update user to be admin and linked to household
              await _firestore.collection('users').doc(user.uid).update({
                'householdId': newHousehold.id,
                'isAdmin': true,
              });

              Navigator.pop(context);
              _loadHouseholdData();
            },
            child: const Text("Create"),
          )
        ],
      ),
    );
  }

  Future<void> _changeHouseholdName() async {
    final controller = TextEditingController(text: _householdName);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Change Household Name"),
        content: TextField(controller: controller),
        actions: [
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty || _householdId == null) return;

              await _firestore
                  .collection('households')
                  .doc(_householdId)
                  .set({'name': name}, SetOptions(merge: true));

              Navigator.pop(context);
              _loadHouseholdData();
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }

Future<void> _addMember() async {
  final controller = TextEditingController();
  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Invite Member"),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(labelText: "Member Email"),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            final email = controller.text.trim();
            if (email.isEmpty || _householdId == null) return;

            final userQuery = await _firestore
                .collection('users')
                .where('email', isEqualTo: email)
                .limit(1)
                .get();

            if (userQuery.docs.isNotEmpty) {
              final invitedUserId = userQuery.docs.first.id;
              final inviterUid = _auth.currentUser!.uid;

              // ✅ Create notification document instead of direct addition
              await _firestore.collection('notifications').add({
                'toUid': invitedUserId,
                'fromUid': inviterUid,
                'householdId': _householdId,
                'type': 'household_invite',
                'status': 'pending',
                'timestamp': FieldValue.serverTimestamp(),
              });

              // Optional: show confirmation
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Invitation sent successfully")),
                );
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("User not found")),
              );
            }
          },
          child: const Text("Send Invite"),
        )
      ],
    ),
  );
}

  Future<void> _removeMember(String memberId) async {
    if (_householdId == null) return;
    await _firestore.collection('households').doc(_householdId).set({
      'members': FieldValue.arrayRemove([memberId]),
    }, SetOptions(merge: true));

    await _firestore.collection('users').doc(memberId).set({
      'householdId': null,
      'isAdmin': false,
    }, SetOptions(merge: true));

    _loadHouseholdData();
  }

  Future<void> _leaveHousehold() async {
    final user = _auth.currentUser;
    if (user == null || _householdId == null) return;

    await _firestore.collection('households').doc(_householdId).set({
      'members': FieldValue.arrayRemove([user.uid]),
    }, SetOptions(merge: true));

    await _firestore.collection('users').doc(user.uid).set({
      'householdId': null,
      'isAdmin': false,
    }, SetOptions(merge: true));

    _loadHouseholdData();
  }

  Future<void> _deleteHousehold() async {
    if (_householdId == null) return;

    final confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Household?"),
        content: const Text(
            "This will remove all members and delete the household permanently."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Delete")),
        ],
      ),
    );

    if (confirm != true) return;

    final members = _members.map((m) => m['id']).toList();

    for (final memberId in members) {
      await _firestore.collection('users').doc(memberId).set({
        'householdId': null,
        'isAdmin': false,
      }, SetOptions(merge: true));
    }

    await _firestore.collection('households').doc(_householdId).delete();
    _loadHouseholdData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_householdId == null) {
      return Center(
        child: ElevatedButton(
          onPressed: _createHousehold,
          child: const Text("Create Household"),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "🏠 $_householdName",
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text("Members:"),
            for (final member in _members)
              ListTile(
                title: Text(member['name']),
                subtitle: Text(member['email']),
                trailing: _isAdmin && member['id'] != _auth.currentUser!.uid
                    ? IconButton(
                        icon:
                            const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () => _removeMember(member['id']),
                      )
                    : null,
              ),
            const SizedBox(height: 10),
            if (_isAdmin) ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.person_add),
                onPressed: _addMember,
                label: const Text("Add Member"),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.edit),
                onPressed: _changeHouseholdName,
                label: const Text("Change Name"),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.delete),
                style:
                    ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: _deleteHousehold,
                label: const Text("Delete Household"),
              ),
            ] else
              ElevatedButton.icon(
                icon: const Icon(Icons.exit_to_app),
                onPressed: _leaveHousehold,
                label: const Text("Leave Household"),
              ),
          ],
        ),
      ),
    );
  }
}
