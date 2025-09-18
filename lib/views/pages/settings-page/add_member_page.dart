import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddMemberPage extends StatefulWidget {
  const AddMemberPage({super.key});

  @override
  State<AddMemberPage> createState() => _AddMemberPageState();
}

class _AddMemberPageState extends State<AddMemberPage> {
  final TextEditingController _usernameController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  /// 🔹 Sends an invite notification instead of directly adding the member
  Future<void> _searchAndInviteMember() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String username = _usernameController.text.trim();
      if (username.isEmpty) {
        setState(() => _errorMessage = "Please enter a username");
        return;
      }

      // 🔹 Search user by username
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        setState(() => _errorMessage = "User not found");
        return;
      }

      final userDoc = query.docs.first;
      final userData = userDoc.data();
      final toUid = userData['uid']; // invited user

      final fromUid = FirebaseAuth.instance.currentUser!.uid; // inviter

      // TODO: Replace with actual householdId (e.g. stored in user profile or passed to page)
      final householdId = fromUid; // for now, use inviter’s uid as householdId

      // 🔹 Check if an invite already exists
      final existingInvite = await FirebaseFirestore.instance
          .collection('notifications')
          .where('toUid', isEqualTo: toUid)
          .where('fromUid', isEqualTo: fromUid)
          .where('householdId', isEqualTo: householdId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingInvite.docs.isNotEmpty) {
        setState(() => _errorMessage = "Invite already sent");
        return;
      }

      // 🔹 Send invite notification
      await FirebaseFirestore.instance.collection('notifications').add({
        'toUid': toUid,
        'fromUid': fromUid,
        'householdId': householdId,
        'type': 'household_invite',
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      Navigator.pop(context, userData['username']); // return invited username
    } catch (e) {
      setState(() => _errorMessage = "Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 240, 240, 241),
      appBar: AppBar(title: const Text("Add Household Member")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: "Enter username",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null)
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _searchAndInviteMember,
                    child: const Text("Send Invite"),
                  ),
          ],
        ),
      ),
    );
  }
}
