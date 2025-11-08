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

  final _fire = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? currentEmail;
  String? householdId;
  String? userRole;

  @override
  void initState() {
    super.initState();
    _initContext();
  }

  Future<void> _initContext() async {
    final user = _auth.currentUser;
    if (user == null) return;
    currentEmail = user.email;
    if (currentEmail == null) return;
    final userSnap = await _fire.collection('users').doc(currentEmail).get();
    final udata = userSnap.data();
    setState(() {
      householdId = udata?['householdId'];
      userRole = udata?['role'];
    });
  }

  Future<void> _searchAndInviteMember() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (householdId == null) {
        setState(() => _errorMessage = "You are not in a household.");
        return;
      }

      if (!(userRole == 'owner' || userRole == 'admin')) {
        setState(
          () => _errorMessage = "Only household owners or admins can invite.",
        );
        return;
      }

      String username = _usernameController.text.trim();
      if (username.isEmpty) {
        setState(() => _errorMessage = "Please enter a username");
        return;
      }

      // Search user by username (exact)
      final query = await _fire
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        setState(() => _errorMessage = "User not found");
        return;
      }

      final userDoc = query.docs.first;
      final toEmail = userDoc.id;
      final toData = userDoc.data();

      // Check invited user is not already in a household
      if (toData['householdId'] != null) {
        setState(
          () => _errorMessage = "This user already belongs to a household.",
        );
        return;
      }

      final fromEmail = currentEmail!;

      // Check for existing pending invite
      final existing = await _fire
          .collection('householdInvites')
          .where('toEmail', isEqualTo: toEmail)
          .where('householdId', isEqualTo: householdId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        setState(() => _errorMessage = "Invite already sent to this user.");
        return;
      }

      // Create invite
      await _fire.collection('householdInvites').add({
        'toEmail': toEmail,
        'fromEmail': fromEmail,
        'householdId': householdId,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context, toData['username'] ?? toEmail);
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
