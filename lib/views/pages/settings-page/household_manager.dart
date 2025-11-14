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
      final userDoc = await _firestore
          .collection('users')
          .doc(user.email)
          .get();
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

      final householdDoc = await _firestore
          .collection('households')
          .doc(householdId)
          .get();

      if (householdDoc.exists) {
        final data = householdDoc.data() ?? {};
        final memberEmails = List<String>.from(data['members'] ?? []);

        final membersData = await Future.wait(
          memberEmails.map((email) async {
            final doc = await _firestore.collection('users').doc(email).get();
            final d = doc.data() ?? {};
            return {'email': email, 'name': d['name'] ?? 'Unknown'};
          }),
        );

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

              // Create household document using email for admin and members
              final newHousehold = await _firestore.collection('households').add({
                'name': name,
                // Creator is owner but NOT auto-admin. Admin chosen via voting.
                'adminId': null,
                'members': [user.email],
                'admins': [],
              });

              await _firestore.collection('users').doc(user.email).update({
                'householdId': newHousehold.id,
                'isAdmin': false,
                'role': 'owner',
              });

              Navigator.pop(context);
              _loadHouseholdData();
            },
            child: const Text("Create"),
          ),
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

              await _firestore.collection('households').doc(_householdId).set({
                'name': name,
              }, SetOptions(merge: true));

              Navigator.pop(context);
              _loadHouseholdData();
            },
            child: const Text("Save"),
          ),
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

              // Check if user exists
              final userDoc = await _firestore
                  .collection('users')
                  .doc(email)
                  .get();
              if (!userDoc.exists) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text("User not found")));
                return;
              }

              // Create a notification for invitation
              await _firestore
                  .collection('users')
                  .doc(email)
                  .collection('notifications')
                  .add({
                    'fromEmail': _auth.currentUser!.email,
                    'type': 'household_invite',
                    'status': 'pending',
                    'sentAt': FieldValue.serverTimestamp(),
                  });

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Invitation sent successfully")),
                );
              }
            },
            child: const Text("Send Invite"),
          ),
        ],
      ),
    );
  }

  Future<void> _removeMember(String email) async {
    if (_householdId == null) return;

    await _firestore.collection('households').doc(_householdId).set({
      'members': FieldValue.arrayRemove([email]),
    }, SetOptions(merge: true));

    await _firestore.collection('users').doc(email).set({
      'householdId': null,
      'isAdmin': false,
    }, SetOptions(merge: true));

    _loadHouseholdData();
  }

  Future<void> _leaveHousehold() async {
    final user = _auth.currentUser;
    if (user == null || _householdId == null) return;

    await _firestore.collection('households').doc(_householdId).set({
      'members': FieldValue.arrayRemove([user.email]),
    }, SetOptions(merge: true));

    await _firestore.collection('users').doc(user.email).set({
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
          "This will remove all members and delete the household permanently.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final members = _members.map((m) => m['email']).toList();

    for (final email in members) {
      await _firestore.collection('users').doc(email).set({
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
              _householdName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text("Members:"),
            for (final member in _members)
              ListTile(
                title: Text(member['name']),
                subtitle: Text(member['email']),
                trailing:
                    _isAdmin && member['email'] != _auth.currentUser!.email
                    ? IconButton(
                        icon: const Icon(
                          Icons.remove_circle,
                          color: Colors.red,
                        ),
                        onPressed: () => _removeMember(member['email']),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
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
