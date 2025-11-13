import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MemberProfilePage extends StatefulWidget {
  final String memberId; // Firestore document id (email) of the member

  const MemberProfilePage({super.key, required this.memberId});

  @override
  State<MemberProfilePage> createState() => _MemberProfilePageState();
}

class _MemberProfilePageState extends State<MemberProfilePage> {
  String? _photoUrl;
  String? _name;
  String? _email;
  String? _role;
  bool _loading = true;
  List<Map<String, dynamic>> _activities = [];
  String? householdId;
  String? householdName;
  String? currentEmail;
  String? currentUserRole;

  final _fire = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadMemberProfile();
  }

  Future<void> _loadMemberProfile() async {
    setState(() => _loading = true);
    try {
      final doc = await _fire.collection('users').doc(widget.memberId).get();

      if (doc.exists) {
        final data = doc.data()!;
        _photoUrl = data['photoUrl'];
        _name = data['username'] ?? data['name'] ?? "No Name";
        _email = data['email'] ?? "No Email";
        _role = data['role'] ?? "Member";
        householdId = data['householdId'];

        if (householdId != null) {
          final h = await _fire.collection('households').doc(householdId).get();
          if (h.exists) {
            householdName = h.data()!['name'];
          }
        }

        final activitySnap = await _fire
            .collection('users')
            .doc(widget.memberId)
            .collection('activities')
            .orderBy('time', descending: true)
            .limit(10)
            .get();

        _activities = activitySnap.docs.map((d) {
          final adata = d.data();
          return {
            "time": adata['time']?.toString() ?? "",
            "action": adata['action'] ?? "",
          };
        }).toList();

        final me = _auth.currentUser;
        if (me != null) {
          currentEmail = me.email;
          if (currentEmail != null) {
            final myDoc = await _fire
                .collection('users')
                .doc(currentEmail)
                .get();
            currentUserRole = myDoc.data()?['role'];
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading member profile: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _promoteToAdmin() async {
    if (currentUserRole != 'owner') {
      _showInfo("Only owner can promote.");
      return;
    }
    if (widget.memberId == currentEmail) {
      _showInfo("You are already the owner/admin.");
      return;
    }
    if (householdId == null) {
      _showInfo("Member is not in a household.");
      return;
    }

    try {
      final hRef = _fire.collection('households').doc(householdId);
      final hSnap = await hRef.get();
      if (!hSnap.exists) return;
      final data = hSnap.data()!;
      final admins = List<String>.from(data['admins'] ?? []);
      if (!admins.contains(widget.memberId)) {
        admins.add(widget.memberId);
        await hRef.update({'admins': admins});
        await _fire.collection('users').doc(widget.memberId).set({
          'role': 'admin',
        }, SetOptions(merge: true));
        await _loadMemberProfile();
        _showInfo("Promoted to admin.");
      } else {
        _showInfo("Already an admin.");
      }
    } catch (e) {
      _showInfo("Error: $e");
    }
  }

  Future<void> _removeFromHousehold() async {
    if (!(currentUserRole == 'owner' || currentUserRole == 'admin')) {
      _showInfo("Only owner/admin can remove members.");
      return;
    }
    if (householdId == null) {
      _showInfo("Member not in a household.");
      return;
    }
    if (widget.memberId == currentEmail && currentUserRole == 'owner') {
      _showInfo("Owner cannot remove themselves here.");
      return;
    }

    try {
      final hRef = _fire.collection('households').doc(householdId);
      await _fire.runTransaction((tx) async {
        final snap = await tx.get(hRef);
        if (!snap.exists) throw Exception("Household missing.");
        final data = snap.data()!;
        final members = List<String>.from(data['members'] ?? []);
        final admins = List<String>.from(data['admins'] ?? []);
        members.remove(widget.memberId);
        admins.remove(widget.memberId);
        tx.update(hRef, {'members': members, 'admins': admins});
        tx.update(_fire.collection('users').doc(widget.memberId), {
          'householdId': null,
          'role': null,
        });
      });
      _showInfo("Member removed.");
      await _loadMemberProfile();
    } catch (e) {
      _showInfo("Error removing: $e");
    }
  }

  void _showInfo(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Member Profile",
          style: TextStyle(color: Colors.black87),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundImage: _photoUrl != null
                                ? NetworkImage(_photoUrl!)
                                : null,
                            backgroundColor: Colors.grey[300],
                            child: _photoUrl == null
                                ? const Icon(
                                    Icons.person,
                                    size: 40,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _name ?? "User",
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _email ?? "No Email",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      _role ?? "Member",
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    if (householdName != null)
                                      Text(
                                        "• $householdName",
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.black45,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Text(
                        "RECENT ACTIVITY",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _activities.isEmpty
                          ? const Text(
                              "No recent activity",
                              style: TextStyle(color: Colors.grey),
                            )
                          : Column(
                              children: _activities
                                  .map(
                                    (a) => ActivityItem(
                                      time: a["time"] ?? "",
                                      action: a["action"] ?? "",
                                    ),
                                  )
                                  .toList(),
                            ),
                    ),

                    const SizedBox(height: 20),

                    // Owner-only actions (promote / remove)
                    if (currentUserRole == 'owner') ...[
                      ElevatedButton(
                        onPressed: _promoteToAdmin,
                        child: const Text("Promote to Admin"),
                      ),
                      const SizedBox(height: 8),
                    ],

                    if (currentUserRole == 'owner' ||
                        currentUserRole == 'admin') ...[
                      ElevatedButton(
                        onPressed: _removeFromHousehold,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text("Remove from Household"),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

class ActivityItem extends StatelessWidget {
  final String time;
  final String action;

  const ActivityItem({super.key, required this.time, required this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              time,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              action,
              style: const TextStyle(color: Colors.black87, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
