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
  List<String> members = [];
  List<String> admins = [];
  bool isLoading = true;

  DocumentReference? userDocRef;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) return;

    try {
      userDocRef = FirebaseFirestore.instance.collection('users').doc(email);
      final doc = await userDocRef!.get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          householdAddress = {
            "line1": data["addressLine1"] ?? "",
            "line2": data["addressLine2"] ?? "",
            "district": data["district"] ?? "",
            "state": data["state"] ?? "",
            "postcode": data["postalCode"] ?? "",
            "country": data["country"] ?? "",
          };
          members = List<String>.from(data["members"] ?? []);
          admins = List<String>.from(data["admins"] ?? []);
          isLoading = false;
        });
      } else {
        await userDocRef!.set({
          "email": email,
          "addressLine1": "",
          "addressLine2": "",
          "district": "",
          "state": "",
          "postalCode": "",
          "country": "",
          "members": [],
          "admins": [],
        });
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("Error loading data: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _updateDocument(Map<String, dynamic> updatedData) async {
    if (userDocRef == null) return;

    try {
      await userDocRef!.set(updatedData, SetOptions(merge: true));
      await _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error updating: $e")));
    }
  }

  Widget _buildCard({
    required String title,
    required List<Widget> children,
    required List<Widget> actions,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) Icon(icon, color: Colors.blue.shade600),
              if (icon != null) const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              ...actions,
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildMemberCard(String name, int index) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border.all(color: Colors.blue.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
          TextButton(
            onPressed: () async {
              members.removeAt(index);
              await _updateDocument({"members": members});
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Remove"),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminCard(String name, int index) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.green[50],
        border: Border.all(color: Colors.green.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
          TextButton(
            onPressed: () async {
              admins.removeAt(index);
              await _updateDocument({"admins": admins});
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Remove"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 240, 240, 241),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    const Center(
                      child: Text(
                        "Settings",
                        style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Household Address
                    _buildCard(
                      title: "Household Address",
                      icon: Icons.home,
                      actions: [
                        ElevatedButton(
                          onPressed: () async {
                            if (householdAddress == null) return;
                            final newAddress = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    EditAddressPage(address: householdAddress!),
                              ),
                            );

                            if (newAddress != null) {
                              setState(() {
                                householdAddress = {
                                  "line1": newAddress["addressLine1"] ?? "",
                                  "line2": newAddress["addressLine2"] ?? "",
                                  "district": newAddress["district"] ?? "",
                                  "state": newAddress["state"] ?? "",
                                  "postcode": newAddress["postalCode"] ?? "",
                                  "country": newAddress["country"] ?? "",
                                };
                              });
                              await _updateDocument(newAddress);
                            }
                          },
                          child: const Text("Edit"),
                        ),
                      ],
                      children: [
                        Text(
                          [
                            householdAddress!['line1'],
                            householdAddress?['line2'],
                          ].where((e) => e!.isNotEmpty).join(", "),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          [
                            householdAddress!['district'],
                            householdAddress!['state'],
                            householdAddress!['postcode'],
                            householdAddress!['country'],
                          ].where((e) => e!.isNotEmpty).join(", "),
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),

                    // Members
                    _buildCard(
                      title: "Household Members",
                      icon: Icons.group,
                      actions: [
                        ElevatedButton(
                          onPressed: () async {
                            final newMember = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AddMemberPage()),
                            );
                            if (newMember != null && newMember.isNotEmpty) {
                              members.add(newMember);
                              await _updateDocument({"members": members});
                            }
                          },
                          child: const Text("Add Member"),
                        ),
                      ],
                      children: [
                        Column(
                          children: List.generate(
                            members.length,
                            (index) => _buildMemberCard(members[index], index),
                          ),
                        ),
                      ],
                    ),

                    // Admins
                    _buildCard(
                      title: "Household Admins",
                      icon: Icons.admin_panel_settings,
                      actions: [
                        ElevatedButton(
                          onPressed: () async {
                            final newAdmin = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddAdminPage(members: members),
                              ),
                            );
                            if (newAdmin != null && newAdmin.isNotEmpty) {
                              admins.add(newAdmin);
                              await _updateDocument({"admins": admins});
                            }
                          },
                          child: const Text("Add Admin"),
                        ),
                      ],
                      children: [
                        Column(
                          children: List.generate(
                            admins.length,
                            (index) => _buildAdminCard(admins[index], index),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
