import 'dart:io';
import 'edit_profile_page.dart';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? _photoUrl;
  String? _name;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final email = user.email!;
    try {
      DocumentSnapshot doc =
          await FirebaseFirestore.instance.collection('users').doc(email).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _photoUrl = data['photoUrl'];
          _name = data['name'] ?? "No Name";
          _loading = false;
        });
      } else {
        await FirebaseFirestore.instance.collection('users').doc(email).set({
          "email": email,
          "name": "",
          "photoUrl": null,
        });
        setState(() {
          _photoUrl = null;
          _name = "No Name";
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading profile: $e")),
      );
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final file = File(pickedFile.path);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final uid = user.uid;

      final ref =
          FirebaseStorage.instance.ref().child('profilePictures/$uid/profile.jpg');

      await ref.putFile(file);

      final downloadUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.email)
          .update({'photoUrl': downloadUrl});

      setState(() {
        _photoUrl = downloadUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile picture updated!")),
      );
    } catch (e) {
      debugPrint("Error uploading image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error uploading image: $e")),
      );
    }
  }

  Future<void> _navigateToEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfilePage()),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _photoUrl = result['photoUrl'] ?? _photoUrl;
        _name = result['name'] ?? _name;
      });
    }
  }

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
                    // Profile Card (dark mode)
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
                          GestureDetector(
                            onTap: _pickAndUploadImage,
                            child: CircleAvatar(
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
                                ElevatedButton(
                                  onPressed: _navigateToEditProfile,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 10,
                                    ),
                                  ),
                                  child: const Text(
                                    "EDIT",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
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
                          color: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Activity Card (dark style)
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
                      child: const Column(
                        children: [
                          ActivityItem(
                            time: "7:45 PM",
                            action: "Turned on room lights",
                          ),
                          ActivityItem(
                            time: "8:30 PM",
                            action: "Opened parcel box",
                          ),
                          ActivityItem(
                            time: "8:45 PM",
                            action: "Retracted clothes hanger",
                          ),
                          ActivityItem(
                            time: "9:00 PM",
                            action: "Turned off room lights",
                          ),
                        ],
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
                color: Colors.white54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              action,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
