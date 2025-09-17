import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'edit_address_page.dart';
import 'add_member_page.dart';
import 'member_profile_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Map<String, String>? householdAddress;
  List<Map<String, dynamic>> members = [];
  String? householdId;
  String uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _loadUserAndHousehold();
  }

  /// 🔹 Load user & household info
  Future<void> _loadUserAndHousehold() async {
    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final userData = userDoc.data() as Map<String, dynamic>?;

      if (userData == null) return;

      setState(() {
        householdId = userData['householdId'];
      });

      if (householdId != null) {
        _loadAddress();
        _loadMembers();
      }
    } catch (e) {
      debugPrint("⚠️ Error loading user: $e");
    }
  }

  /// 🔹 Load household address
  Future<void> _loadAddress() async {
    try {
      final householdDoc = await FirebaseFirestore.instance
          .collection('households')
          .doc(householdId)
          .get();

      if (householdDoc.exists) {
        final data = householdDoc.data() as Map<String, dynamic>;
        setState(() {
          householdAddress = {
            "addressLine1": data["addressLine1"] ?? "",
            "addressLine2": data["addressLine2"] ?? "",
            "city": data["city"] ?? "",
            "state": data["state"] ?? "",
            "postalCode": data["postalCode"] ?? "",
          };
        });
      }
    } catch (e) {
      debugPrint("⚠️ Error loading address: $e");
    }
  }

  /// 🔹 Load members by householdId
  Future<void> _loadMembers() async {
    try {
      final membersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('householdId', isEqualTo: householdId)
          .get();

      setState(() {
        members = membersSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            "id": doc.id,
            "name": data['name'] ?? data['username'] ?? "Unknown",
            "email": data['email'] ?? "",
            "role": data['role'] ?? "Member",
          };
        }).toList();
      });
    } catch (e) {
      debugPrint("⚠️ Error loading members: $e");
    }
  }

  /// 🔹 Leave household
  Future<void> _leaveHousehold() async {
    if (householdId == null) return;

    await FirebaseFirestore.instance.runTransaction((tx) async {
      tx.update(FirebaseFirestore.instance.collection('users').doc(uid), {
        'householdId': null,
        'role': null,
      });
      tx.update(
          FirebaseFirestore.instance.collection('households').doc(householdId),
          {
            'members': FieldValue.arrayRemove([uid]),
          });
    });

    setState(() {
      householdId = null;
      members = [];
      householdAddress = null;
    });
  }

  /// 🔹 Accept invite
  Future<void> _acceptInvite(DocumentSnapshot inviteDoc) async {
    if (householdId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Leave your current household before joining another")),
      );
      return;
    }

    final householdRef = inviteDoc.reference.parent.parent!;

    await FirebaseFirestore.instance.runTransaction((tx) async {
      tx.update(inviteDoc.reference, {'status': 'accepted'});
      tx.update(FirebaseFirestore.instance.collection('users').doc(uid), {
        'householdId': householdRef.id,
        'role': 'Member',
      });
      tx.update(householdRef, {
        'members': FieldValue.arrayUnion([uid]),
      });
    });

    _loadUserAndHousehold();
  }

  /// 🔹 Reject invite
  Future<void> _rejectInvite(DocumentSnapshot inviteDoc) async {
    await inviteDoc.reference.update({'status': 'rejected'});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.grey),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Settings",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              const SizedBox(height: 24),

              /// Household Address
              const Text("Household Address",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              householdAddress == null
                  ? const Text("No household joined",
                      style: TextStyle(color: Colors.grey))
                  : Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        border: Border.all(color: Colors.blue.shade200),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            householdAddress!['addressLine1']!.isNotEmpty
                                ? "${householdAddress!['addressLine1']}, ${householdAddress!['addressLine2']}"
                                : "No address set",
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${householdAddress!['city']}, ${householdAddress!['state']} ${householdAddress!['postalCode']}",
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 14),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            onPressed: _leaveHousehold,
                            child: const Text("Leave Household"),
                          )
                        ],
                      ),
                    ),

              const SizedBox(height: 24),

              /// Household Members
              if (householdId != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Household Members",
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w600)),
                    IconButton(
                      icon: const Icon(Icons.add_circle,
                          color: Colors.blue, size: 30),
                      onPressed: () async {
                        final newMember = await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AddMemberPage()),
                        );
                        if (newMember != null) {
                          _loadMembers(); // reload after adding
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                members.isEmpty
                    ? const Text("No members yet",
                        style: TextStyle(color: Colors.grey))
                    : Column(
                        children: members.map((m) {
                          return ListTile(
                            leading: const Icon(Icons.person),
                            title: Text(m["name"]!),
                            subtitle: Text("${m["email"]} • ${m["role"]}"),
                            trailing:
                                const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      MemberProfilePage(memberId: m["id"]!),
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ),
              ],

              const SizedBox(height: 24),

              /// Pending Invites
              const Text("Invites",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              StreamBuilder(
                stream: FirebaseFirestore.instance
                    .collectionGroup('invites')
                    .where('invitedUserId', isEqualTo: uid)
                    .where('status', isEqualTo: 'pending')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.data!.docs.isEmpty) {
                    return const Text("No pending invites",
                        style: TextStyle(color: Colors.grey));
                  }
                  
                  return Column(
                    children: snapshot.data!.docs.map((doc) {
                      final householdId = doc.reference.parent.parent!.id;
                      return Card(
                        child: ListTile(
                          title: Text("Invite to Household: $householdId"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check,
                                    color: Colors.green),
                                onPressed: () => _acceptInvite(doc),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.close, color: Colors.red),
                                onPressed: () => _rejectInvite(doc),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
