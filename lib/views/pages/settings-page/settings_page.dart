import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'edit_address_page.dart';
import 'add_member_page.dart';
import 'add_admin_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Map<String, String>? householdAddress;

  @override
  void initState() {
    super.initState();
    _loadAddress();
  }

  Future<void> _loadAddress() async {
  String uid = FirebaseAuth.instance.currentUser!.uid;
  DocumentSnapshot doc =
      await FirebaseFirestore.instance.collection('users').doc(uid).get();

  if (doc.exists) {
    final data = doc.data() as Map<String, dynamic>;
    setState(() {
      householdAddress = {
        "line1": data["addressLine1"] ?? "",
        "line2": data["addressLine2"] ?? "",
        "city": data["city"] ?? "",
        "state": data["state"] ?? "",
        "postcode": data["postalCode"] ?? "",
      };
    });
  }
}



  List<String> members = ["John Doe", "Jane Doe"];
  List<String> admins = ["User Admin"];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Settings",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 30, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),

// Household Address
const Text(
  "Household Address",
  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
),
const SizedBox(height: 12),

householdAddress == null
    ? const Center(child: CircularProgressIndicator())
    : Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          border: Border.all(color: Colors.blue.shade200),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${householdAddress!['line1']}, ${householdAddress!['line2']}",
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  "${householdAddress!['city']}, ${householdAddress!['state']} ${householdAddress!['postcode']}",
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: () async {
                final newAddress = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditAddressPage(address: householdAddress!),
                  ),
                );
                if (newAddress != null) {
                  String uid = FirebaseAuth.instance.currentUser!.uid;
                  await FirebaseFirestore.instance.collection('users').doc(uid).update({
                    'address': newAddress,
                  });

                  setState(() {
                    householdAddress = Map<String, String>.from(newAddress);
                  });
                }
              },
              child: const Text("Edit"),
            ),
          ],
        ),
      ),


              // Household Members
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Household Members",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () async {
                      final newMember = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddMemberPage()),
                      );
                      if (newMember != null && newMember.isNotEmpty) {
                        setState(() {
                          members.add(newMember);
                        });
                      }
                    },
                    child: const Text("Add Member"),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (var i = 0; i < members.length; i++)
                    _buildMemberCard(members[i], "Member", Colors.blue[100]!, "U${i + 1}", i),
                ],
              ),

              const SizedBox(height: 32),

              // Household Admins
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Household Admins",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () async {
                      final votedUser = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddAdminPage(members: members),
                        ),
                      );
                      if (votedUser != null && !admins.contains(votedUser)) {
                        setState(() {
                          admins.add(votedUser);
                        });
                      }
                    },
                    child: const Text("Add Admin"),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (var i = 0; i < admins.length; i++)
                    _buildAdminCard(admins[i], "Admin", Colors.green[100]!, "A${i + 1}", i),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🔹 Household Member Card
  Widget _buildMemberCard(String name, String role, Color bgColor, String initials, int index) {
    return Container(
      width: 350,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: bgColor,
                child: Text(initials, style: const TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  Text(role, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ],
          ),
          TextButton(
            onPressed: () {
              setState(() {
                members.removeAt(index);
              });
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Remove"),
          ),
        ],
      ),
    );
  }

  // 🔹 Admin Card
  Widget _buildAdminCard(String name, String role, Color bgColor, String initials, int index) {
    return Container(
      width: 350,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        border: Border.all(color: Colors.green.shade200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: bgColor,
                child: Text(initials, style: const TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  Text(role, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ],
          ),
          TextButton(
            onPressed: () {
              setState(() {
                admins.removeAt(index);
              });
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Remove"),
          ),
        ],
      ),
    );
  }
}
