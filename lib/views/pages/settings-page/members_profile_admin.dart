// member_profile_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MemberProfilePage extends StatefulWidget {
  final String memberEmail;
  
  const MemberProfilePage({
    super.key,
    required this.memberEmail,
  });

  @override
  State<MemberProfilePage> createState() => _MemberProfilePageState();
}

class _MemberProfilePageState extends State<MemberProfilePage> {
  String? _photoUrl;
  String? _name;
  bool _loading = true;
  List<Map<String, dynamic>> _activities = [];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  // Helper function to format timestamp
  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();

    // Format date as dd/mm/yy
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString().substring(2);

    // Format time as 15:40 (24-hour format)
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }

  Future<void> _loadUserProfile() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.memberEmail)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        // load activity log for this user (if household exists)
        final householdId = data['householdId'] as String?;
        if (householdId != null && householdId.isNotEmpty) {
          final snap = await FirebaseFirestore.instance
              .collection('households')
              .doc(householdId)
              .collection('members')
              .doc(widget.memberEmail)
              .collection('activityLog')
              .orderBy('timestamp', descending: true)
              .limit(20)
              .get();
          _activities = snap.docs.map((d) {
            final m = d.data();
            final timestamp = m['timestamp'] as Timestamp?;
            return {
              'time': timestamp != null ? _formatTimestamp(timestamp) : '',
              'action': m['action'] ?? '',
            };
          }).toList();
        } else {
          _activities = [];
        }
        setState(() {
          _photoUrl = data['photoUrl'];
          _name = data['name'] ?? "No Name";
          _loading = false;
        });
      } else {
        _activities = [];
        setState(() {
          _photoUrl = null;
          _name = "No Name";
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error loading profile: $e")));
      }
    }
  }

  // REMOVED: _pickAndUploadImage() - Admin cannot edit member's profile picture
  // REMOVED: _navigateToEditProfile() - Admin cannot edit member's profile

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220), // dark background
      appBar: AppBar(
        backgroundColor: const Color(0xFF07101A),
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Profile",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white70),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Card (dark mode) - EXACTLY SAME
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade800),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 6),
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
                            backgroundColor: Colors.grey.shade700,
                            child: _photoUrl == null
                                ? const Icon(
                                    Icons.person,
                                    size: 40,
                                    color: Colors.white70,
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
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // EDIT BUTTON REMOVED - Admin cannot edit member's profile
                                // ElevatedButton(
                                //   onPressed: _navigateToEditProfile,
                                //   style: ElevatedButton.styleFrom(
                                //     backgroundColor: const Color(0xFF2563EB),
                                //     foregroundColor: Colors.white,
                                //     shape: RoundedRectangleBorder(
                                //       borderRadius: BorderRadius.circular(10),
                                //     ),
                                //     padding: const EdgeInsets.symmetric(
                                //       horizontal: 18,
                                //       vertical: 10,
                                //     ),
                                //   ),
                                //   child: const Text(
                                //     "EDIT",
                                //     style: TextStyle(
                                //       fontSize: 14,
                                //       fontWeight: FontWeight.w500,
                                //     ),
                                //   ),
                                // ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Recent Activity Title - EXACTLY SAME
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Text(
                        "RECENT ACTIVITY",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Activity Card (loaded from Firestore) - EXACTLY SAME
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade800),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: _activities.isEmpty
                          ? Container(
                              height: 60, // Minimum height to match activity items
                              alignment: Alignment.center,
                              child: const Text(
                                "No recent activity",
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 16,
                                ),
                              ),
                            )
                          : Column(
                              children: _activities
                                  .map(
                                    (a) => ActivityItem(
                                      time: a['time'] ?? '',
                                      action: a['action'] ?? '',
                                    ),
                                  )
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
            width: 120, // Increased width to accommodate the longer timestamp
            child: Text(
              time,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              action,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}