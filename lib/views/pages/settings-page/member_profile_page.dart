import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class MemberProfilePage extends StatefulWidget {
  final String memberId; // Firestore UID of the member

  const MemberProfilePage({Key? key, required this.memberId}) : super(key: key);

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

  @override
  void initState() {
    super.initState();
    _loadMemberProfile();
  }

  Future<void> _loadMemberProfile() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.memberId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _photoUrl = data['photoUrl'];
          _name = data['name'] ?? "No Name";
          _email = data['email'] ?? "No Email";
          _role = data['role'] ?? "Member";
        });

        // Load recent activities if stored in a subcollection
        final activitySnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.memberId)
            .collection('activities')
            .orderBy('time', descending: true)
            .limit(10)
            .get();

        setState(() {
          _activities = activitySnap.docs.map((d) {
            final adata = d.data();
            return {
              "time": adata['time'] ?? "",
              "action": adata['action'] ?? "",
            };
          }).toList();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading member profile: $e");
      setState(() => _loading = false);
    }
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
                    // Profile Card
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
                                ? const Icon(Icons.person,
                                    size: 40, color: Colors.white)
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
                                Text(
                                  _role ?? "Member",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Recent Activity Title
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

                    // Activity Card
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
                          ? const Text("No recent activity",
                              style: TextStyle(color: Colors.grey))
                          : Column(
                              children: _activities
                                  .map((a) => ActivityItem(
                                      time: a["time"] ?? "",
                                      action: a["action"] ?? ""))
                                  .toList(),
                            ),
                    ),
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
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
