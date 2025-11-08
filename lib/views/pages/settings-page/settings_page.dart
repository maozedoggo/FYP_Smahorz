// settings_page.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:smart_horizon_home/views/pages/settings-page/edit_address_page.dart';
import 'member_profile_page.dart';
import 'household_voting.dart';

/// Redesigned SettingsPage (dark theme + card UI)
class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _auth = FirebaseAuth.instance;
  final _fire = FirebaseFirestore.instance;

  // UI state
  bool isLoading = true;
  bool isSavingHousehold = false;
  bool isSendingInvite = false;

  // current user & household
  String? currentEmail;
  DocumentReference<Map<String, dynamic>>? currentUserDocRef;
  String? householdId;
  DocumentReference<Map<String, dynamic>>? householdDocRef;
  String? userRole; // 'owner' | 'admin' | 'member' | null
  String? householdName;

  // household fields
  String householdAddressText = "";
  List<String> memberEmails = [];
  List<String> adminEmails = [];

  // controllers (household info / invite)
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _inviteEmailCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ---------- Data loading ----------
  Future<void> _loadData() async {
    setState(() => isLoading = true);

    final user = _auth.currentUser;
    if (user == null) {
      setState(() => isLoading = false);
      return;
    }

    // Use email as the document id in the users collection
    currentEmail = user.email;
    if (currentEmail == null) {
      setState(() => isLoading = false);
      return;
    }
    currentUserDocRef = _fire.collection('users').doc(currentEmail);

    try {
      final userSnap = await currentUserDocRef!.get();
      if (!userSnap.exists) {
        // create minimal user doc
        await currentUserDocRef!.set({
          'email': user.email ?? '',
          'username': user.displayName ?? '',
          'householdId': null,
          'role': null,
        });
      }

      final userData = (await currentUserDocRef!.get()).data() ?? {};
      householdId = userData['householdId'];
      userRole = userData['role'];

      // LOAD USER ADDRESS REGARDLESS OF HOUSEHOLD STATUS
      String userAddress = _loadUserAddress(userData);

      if (householdId != null) {
        householdDocRef = _fire.collection('households').doc(householdId);
        final hSnap = await householdDocRef!.get();
        if (hSnap.exists) {
          final hData = hSnap.data()!;

          // LOAD ADDRESS FROM MULTIPLE SOURCES
          String address = "";

          // First, try to get address from household document (where we save it)
          final householdAddress = hData['address']?.toString() ?? '';

          // If household has address, use it
          if (householdAddress.isNotEmpty) {
            address = householdAddress;
          } else {
            // Otherwise, use the user address we loaded earlier
            address = userAddress;
          }

          setState(() {
            householdName = hData['name'] ?? "";
            householdAddressText = address;
            _nameCtrl.text = householdName ?? "";
            _addressCtrl.text = householdAddressText;
            memberEmails = List<String>.from(hData['members'] ?? []);
            adminEmails = List<String>.from(hData['admins'] ?? []);
          });

          debugPrint("=== ADDRESS DEBUG ===");
          debugPrint("Household Name: $householdName");
          debugPrint("Final Address: $householdAddressText");
          debugPrint("Address Controller Text: ${_addressCtrl.text}");
          debugPrint("=== END DEBUG ===");
        } else {
          // household doc missing — clear user
          await currentUserDocRef!.set({
            'householdId': null,
            'role': null,
          }, SetOptions(merge: true));
          setState(() {
            householdId = null;
            userRole = null;
            householdName = null;
            memberEmails = [];
            adminEmails = [];
            householdAddressText = userAddress; // Keep user address
            _nameCtrl.clear();
            _addressCtrl.text = userAddress; // Keep user address in controller
          });
        }
      } else {
        // not in any household - STILL SHOW USER ADDRESS
        setState(() {
          householdName = null;
          memberEmails = [];
          adminEmails = [];
          householdAddressText = userAddress;
          _nameCtrl.clear();
          _addressCtrl.text =
              userAddress; // Show user address even without household
        });
      }
    } catch (e) {
      debugPrint("Error loading data: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error loading: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Load user address from user document
  String _loadUserAddress(Map<String, dynamic> userData) {
    final addressLine1 = userData['addressLine1']?.toString() ?? '';
    final addressLine2 = userData['addressLine2']?.toString() ?? '';
    final district = userData['district']?.toString() ?? '';
    final state = userData['state']?.toString() ?? '';
    final postalCode = userData['postalCode']?.toString() ?? '';
    final country = userData['country']?.toString() ?? '';

    // Build address string from non-empty fields
    final addressParts = [
      addressLine1,
      addressLine2,
      district,
      state,
      postalCode,
      country,
    ].where((part) => part.isNotEmpty).toList();

    return addressParts.join(", ");
  }

  // ---------- Household creation ----------
  Future<void> _createHouseholdDialog() async {
    if (householdId != null) {
      _showInfo("You are already in a household.");
      return;
    }
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Create Household"),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: "Household name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter a name.")),
                );
                return;
              }
              Navigator.pop(context);
              await _createHousehold(name);
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  Future<void> _createHousehold(String name) async {
    if (currentEmail == null) return;
    setState(() => isLoading = true);
    try {
      final userSnap = await currentUserDocRef!.get();
      final udata = userSnap.data();
      if (udata != null && udata['householdId'] != null) {
        _showInfo("You are already in a household.");
        return;
      }

      final householdRef = await _fire.collection('households').add({
        'name': name,
        'ownerId': currentEmail,
        'members': [currentEmail],
        'admins': [currentEmail],
        'createdAt': FieldValue.serverTimestamp(),
      });

      await currentUserDocRef!.set({
        'householdId': householdRef.id,
        'role': 'owner',
      }, SetOptions(merge: true));
      await _loadData();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Household created.")));
    } catch (e) {
      debugPrint("Error creating household: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  // ---------- Save household info (admin only) ----------
  Future<void> _saveHouseholdInfo() async {
    if (householdDocRef == null) return;
    if (!(userRole == 'owner' || userRole == 'admin')) {
      _showInfo("You don't have permission to edit.");
      return;
    }

    setState(() => isSavingHousehold = true);
    try {
      final newName = _nameCtrl.text.trim();
      final newAddress = _addressCtrl.text.trim();

      // Save both name and address to household document
      await householdDocRef!.set({
        'name': newName,
        'address': newAddress,
      }, SetOptions(merge: true));

      await _loadData();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Household updated.")));
    } catch (e) {
      debugPrint("Error saving household: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error saving: $e")));
    } finally {
      setState(() => isSavingHousehold = false);
    }
  }

  // ---------- Invite member (by email) ----------
  Future<void> _sendInvite() async {
    if (householdId == null || currentEmail == null) return;
    if (!(userRole == 'owner' || userRole == 'admin')) {
      _showInfo("Only admins can invite members.");
      return;
    }

    final email = _inviteEmailCtrl.text.trim();
    if (email.isEmpty) {
      _showInfo("Enter an email to invite.");
      return;
    }

    setState(() => isSendingInvite = true);
    try {
      // find user by email
      final query = await _fire
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (query.docs.isEmpty) {
        // If user doesn't exist, create notification with email reference
        await _fire.collection('notifications').add({
          'fromEmail': currentEmail,
          'toEmail': email,
          'householdId': householdId,
          'householdName': householdName,
          'type': 'household_invite',
          'status': 'pending',
          'sentAt': FieldValue.serverTimestamp(),
        });
        _inviteEmailCtrl.clear();
        _showInfo("Invite created (user not registered yet).");
        return;
      }

      final userDoc = query.docs.first;
      final toEmail = userDoc.id; // doc id is email
      final userData = userDoc.data();
      if ((userData['householdId'] as String?) != null) {
        _showInfo("User already belongs to a household.");
        return;
      }

      // check existing notification
      final existing = await _fire
          .collection('notifications')
          .where('toEmail', isEqualTo: toEmail)
          .where('householdId', isEqualTo: householdId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        _showInfo("Invite already pending for that user.");
        return;
      }

      await _fire.collection('notifications').add({
        'fromEmail': currentEmail,
        'toEmail': toEmail,
        'householdId': householdId,
        'householdName': householdName,
        'type': 'household_invite',
        'status': 'pending',
        'sentAt': FieldValue.serverTimestamp(),
      });

      _inviteEmailCtrl.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Invite sent.")));
    } catch (e) {
      debugPrint("Error sending invite: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error inviting: $e")));
    } finally {
      setState(() => isSendingInvite = false);
    }
  }

  // ---------- Remove member ----------
  Future<void> _removeMember(String email) async {
    if (householdDocRef == null) return;
    if (!(userRole == 'owner' || userRole == 'admin')) {
      _showInfo("Only owners or admins can remove members.");
      return;
    }
    // don't remove owner
    final hSnap = await householdDocRef!.get();
    final hData = hSnap.data()!;
    final ownerId = hData['ownerId'] as String?;
    if (email == ownerId) {
      _showInfo("Cannot remove the owner. Transfer ownership first.");
      return;
    }

    try {
      await _fire.runTransaction((tx) async {
        final snap = await tx.get(householdDocRef!);
        final data = snap.data()!;
        final members = List<String>.from(data['members'] ?? []);
        final admins = List<String>.from(data['admins'] ?? []);
        members.remove(email);
        admins.remove(email);
        tx.update(householdDocRef!, {'members': members, 'admins': admins});
        final userRef = _fire.collection('users').doc(email);
        tx.update(userRef, {'householdId': null, 'role': null});
      });
      await _loadData();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Member removed.")));
    } catch (e) {
      debugPrint("Error removing member: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error removing: $e")));
    }
  }

  // ---------- Transfer admin (make other user owner/admin) ----------
  Future<void> _transferOwnership(String newOwnerEmail) async {
    if (householdDocRef == null) return;
    if (userRole != 'owner') {
      _showInfo("Only the owner can transfer ownership.");
      return;
    }
    if (newOwnerEmail == currentEmail) {
      _showInfo("You already are the owner.");
      return;
    }

    final name = await _getMemberName(newOwnerEmail) ?? newOwnerEmail;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Transfer Ownership"),
        content: Text(
          "Transfer ownership to $name? You will lose owner rights.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Transfer"),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      // Update household ownerId and admins array, and update user roles
      final hSnap = await householdDocRef!.get();
      final hData = hSnap.data()!;
      final oldOwner = hData['ownerId'] as String?;
      final admins = List<String>.from(hData['admins'] ?? []);

      // ensure newOwner is in admins
      if (!admins.contains(newOwnerEmail)) admins.add(newOwnerEmail);
      // keep old owner in admins (or demote to admin)
      if (oldOwner != null && !admins.contains(oldOwner)) admins.add(oldOwner);

      await _fire.runTransaction((tx) async {
        tx.update(householdDocRef!, {
          'ownerId': newOwnerEmail,
          'admins': admins,
        });
        // set new owner role
        tx.update(_fire.collection('users').doc(newOwnerEmail), {
          'role': 'owner',
        });
        // demote previous owner to admin
        if (oldOwner != null)
          tx.update(_fire.collection('users').doc(oldOwner), {'role': 'admin'});
      });

      await _loadData();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Ownership transferred.")));
    } catch (e) {
      debugPrint("Error transferring ownership: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error transferring: $e")));
    }
  }

  // ---------- Demote admin ----------
  Future<void> _demoteAdmin(String email) async {
    if (householdDocRef == null) return;
    if (userRole != 'owner') {
      _showInfo("Only owner can demote admins.");
      return;
    }
    if (email == currentEmail) {
      _showInfo("Owner cannot demote themselves here.");
      return;
    }

    try {
      final hSnap = await householdDocRef!.get();
      final hData = hSnap.data()!;
      final admins = List<String>.from(hData['admins'] ?? []);
      admins.remove(email);
      await householdDocRef!.update({'admins': admins});
      await _fire.collection('users').doc(email).set({
        'role': 'member',
      }, SetOptions(merge: true));
      await _loadData();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Admin demoted.")));
    } catch (e) {
      debugPrint("Error demoting admin: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error demoting: $e")));
    }
  }

  // ---------- Leave household ----------
  Future<void> _leaveHousehold() async {
    if (householdDocRef == null) return;

    try {
      final hSnap = await householdDocRef!.get();
      final hData = hSnap.data()!;
      final ownerId = hData['ownerId'] as String?;
      if (userRole == 'owner' && currentEmail == ownerId) {
        // confirm deletion
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Delete Household?"),
            content: const Text(
              "You are the owner. Leaving will delete the household and remove all members. Continue?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Delete"),
              ),
            ],
          ),
        );
        if (confirm != true) return;

        // delete household and clear all members
        final members = List<String>.from(hData['members'] ?? []);
        final batch = _fire.batch();
        for (final e in members) {
          final uRef = _fire.collection('users').doc(e);
          batch.update(uRef, {'householdId': null, 'role': null});
        }
        batch.delete(householdDocRef!);
        await batch.commit();

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Household deleted.")));
        await _loadData();
        return;
      }

      // non-owner leave
      final members = List<String>.from(hData['members'] ?? []);
      final admins = List<String>.from(hData['admins'] ?? []);
      members.remove(currentEmail);
      admins.remove(currentEmail);
      await householdDocRef!.update({'members': members, 'admins': admins});
      await _fire.collection('users').doc(currentEmail).update({
        'householdId': null,
        'role': null,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You have left the household.")),
      );
      await _loadData();
    } catch (e) {
      debugPrint("Error leaving household: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error leaving: $e")));
    }
  }

  // ---------- Helpers ----------
  void _showInfo(String message) => showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Info"),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("OK"),
        ),
      ],
    ),
  );

  Future<String?> _getMemberName(String email) async {
    try {
      final snap = await _fire.collection('users').doc(email).get();
      final data = snap.data();
      if (data == null) return null;
      return data['username'] ?? data['email'] ?? email;
    } catch (e) {
      return null;
    }
  }

  // ---------- UI building ----------
  bool get _isAdmin => userRole == 'owner' || userRole == 'admin';

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827), // dark card
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade800),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 8,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }

  Widget _headerRow(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue.shade300),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // Personal Information Card
  Widget _personalInfoCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _headerRow(Icons.person, "Personal Information"),
          const SizedBox(height: 12),

          // Display user info
          FutureBuilder<DocumentSnapshot>(
            future: currentUserDocRef?.get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const CircularProgressIndicator();
              }
              final userData =
                  snapshot.data?.data() as Map<String, dynamic>? ?? {};
              final email = userData['email'] ?? 'No email';
              final name = userData['name'] ?? 'No name';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Name: $name",
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Email: $email",
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 12),

                  // Display address if available
                  if (householdAddressText.isNotEmpty) ...[
                    Text(
                      "Your Address:",
                      style: TextStyle(
                        color: Colors.grey.shade300,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      householdAddressText,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              );
            },
          ),

          // Edit Address Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final user = _auth.currentUser;
                if (user == null) return;

                try {
                  final userDoc = await _fire
                      .collection('users')
                      .doc(user.email)
                      .get();
                  final userData = userDoc.data() ?? {};

                  final updatedAddress = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditAddressPage(
                        initialAddress: {
                          'addressLine1': userData['addressLine1'] ?? '',
                          'addressLine2': userData['addressLine2'] ?? '',
                          'district': userData['district'] ?? '',
                          'state': userData['state'] ?? '',
                          'postalCode': userData['postalCode'] ?? '',
                          'country': userData['country'] ?? 'Malaysia',
                        },
                      ),
                    ),
                  );

                  if (updatedAddress != null) {
                    await _loadData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Address updated successfully!"),
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error loading address: $e")),
                  );
                }
              },
              icon: const Icon(Icons.edit_location_alt, color: Colors.white),
              label: const Text(
                "Edit Personal Address",
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _householdInfoCard() {
    final canEdit = _isAdmin && householdId != null;
    final saveDisabled =
        isSavingHousehold ||
        (_nameCtrl.text.trim() == (householdName ?? "").trim() &&
            _addressCtrl.text.trim() == (householdAddressText).trim());

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _headerRow(Icons.home, "Household Information"),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            enabled: canEdit && !isSavingHousehold,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.home),
              labelText: "Household Name",
              labelStyle: TextStyle(color: Colors.grey.shade300),
              filled: true,
              fillColor: const Color(0xFF0B1220),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressCtrl,
            enabled: canEdit && !isSavingHousehold,
            style: const TextStyle(color: Colors.white),
            maxLines: 2,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.location_on),
              labelText: "Address",
              labelStyle: TextStyle(color: Colors.grey.shade300),
              filled: true,
              fillColor: const Color(0xFF0B1220),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              hintText: householdAddressText.isEmpty ? "No address set" : null,
            ),
          ),
          if (householdAddressText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              "Current Address: $householdAddressText",
              style: TextStyle(color: Colors.green.shade300, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          if (canEdit)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: saveDisabled ? null : _saveHouseholdInfo,
                    icon: isSavingHousehold
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(
                      isSavingHousehold ? "Saving..." : "Save Changes",
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else if (householdId == null)
            Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.blueAccent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "Create a household to edit information.",
                    style: TextStyle(color: Colors.blue.shade100),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Row(
                children: [
                  const Icon(Icons.lock, color: Colors.orangeAccent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "Only admins can edit this information.",
                    style: TextStyle(color: Colors.orange.shade100),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _memberTileWidget(String email) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _fire.collection('users').doc(email).get(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final name = data?['username'] ?? data?['email'] ?? email;
        final role =
            data?['role'] ?? (adminEmails.contains(email) ? 'admin' : 'member');
        final isCurrentUser = email == currentEmail;

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: role.toLowerCase() == 'owner'
                ? Colors.blue.shade900.withOpacity(0.25)
                : const Color(0xFF0B1220),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade800),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (role.toLowerCase() == 'owner') ...[
                          const Icon(
                            Icons.star,
                            size: 16,
                            color: Colors.yellow,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data?['email'] ?? '',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // role text
              Column(
                children: [
                  Text(
                    role.toString(),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  if (_isAdmin && !isCurrentUser)
                    Row(
                      children: [
                        // Remove
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => _removeMember(email),
                          tooltip: "Remove member",
                        ),
                        // Promote / Transfer owner (only owner can transfer)
                        if (userRole == 'owner')
                          IconButton(
                            icon: const Icon(
                              Icons.manage_accounts,
                              color: Colors.orangeAccent,
                            ),
                            onPressed: () => _transferOwnership(email),
                            tooltip: "Transfer ownership",
                          ),
                        // If current user is admin (and not owner), allow promote to admin (simple promote)
                        if (userRole == 'owner' &&
                            role.toString().toLowerCase() != 'owner')
                          IconButton(
                            icon: const Icon(
                              Icons.shield,
                              color: Colors.greenAccent,
                            ),
                            onPressed: () async {
                              // Promote to admin by adding to household admins and updating user role
                              try {
                                final hSnap = await householdDocRef!.get();
                                final hData = hSnap.data()!;
                                final admins = List<String>.from(
                                  hData['admins'] ?? [],
                                );
                                if (!admins.contains(email)) admins.add(email);
                                await householdDocRef!.update({
                                  'admins': admins,
                                });
                                await _fire.collection('users').doc(email).set({
                                  'role': 'admin',
                                }, SetOptions(merge: true));
                                await _loadData();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Promoted to admin."),
                                  ),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Error promoting: $e"),
                                  ),
                                );
                              }
                            },
                            tooltip: "Promote to admin",
                          ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _membersCard() {
    if (householdId == null)
      return const SizedBox(); // Don't show members card if no household

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _headerRow(Icons.group, "Household Members"),
          const SizedBox(height: 12),
          Column(
            children: memberEmails.map((u) => _memberTileWidget(u)).toList(),
          ),
          const SizedBox(height: 12),
          if (_isAdmin)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(color: Colors.grey),
                const SizedBox(height: 8),
                const Text(
                  "Invite New Member",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inviteEmailCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Enter email address",
                          hintStyle: TextStyle(color: Colors.grey.shade500),
                          filled: true,
                          fillColor: const Color(0xFF0B1220),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: isSendingInvite ? null : _sendInvite,
                      icon: isSendingInvite
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send, color: Colors.white,),
                      label: const Text("Send", style: TextStyle(color: Colors.white),),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _adminControlCard() {
    if (householdId == null)
      return const SizedBox(); // Don't show admin card if no household

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _headerRow(Icons.lock, "Administrator Control"),
          const SizedBox(height: 12),
          const Text(
            "The owner/admin has full control over household settings and members.",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 12),
          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: householdDocRef != null
                ? householdDocRef!.get()
                : Future.value(
                    // Create an empty DocumentSnapshot with default values
                    FirebaseFirestore.instance
                        .collection('households')
                        .doc('dummy')
                        .get(),
                  ),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final data = snap.data?.data();
              final ownerId = data != null ? data['ownerId'] as String? : null;
              final ownerNameFuture = ownerId != null
                  ? _getMemberName(ownerId)
                  : Future.value(null);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FutureBuilder<String?>(
                    future: ownerNameFuture,
                    builder: (context, ownerSnap) {
                      final ownerName = ownerSnap.data ?? "N/A";
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Current Owner",
                                style: TextStyle(color: Colors.grey),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                ownerName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if (userRole == 'owner')
                            ElevatedButton(
                              onPressed: () async {
                                // Quick UX: let owner open a dialog with options to transfer to a member
                                final selected = await showDialog<String?>(
                                  context: context,
                                  builder: (_) => TransferOwnerDialog(
                                    members: memberEmails
                                        .where((u) => u != currentEmail)
                                        .toList(),
                                    fire: _fire,
                                  ),
                                );
                                if (selected != null) {
                                  _transferOwnership(selected);
                                }
                              },
                              child: const Text("Transfer Owner", style: TextStyle(color: Color(0xFF111827)),),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade900.withOpacity(0.16),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                "No permission",
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  if (!(_isAdmin))
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade900.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        "You do not have permission to manage admin settings.",
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ---------- Build ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220), // page bg
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF07101A),
        centerTitle: true,
        title: const Text(
          "Household Settings",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  child: Column(
                    children: [
                      // Title
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          householdName ?? "",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Personal Information Card
                      _personalInfoCard(),
                      const SizedBox(height: 16),

                      // CONDITIONAL RENDERING
                      if (householdId == null)
                        Column(
                          children: [
                            _householdInfoCard(),
                            const SizedBox(height: 20),
                            Center(
                              child: ElevatedButton.icon(
                                onPressed: _createHouseholdDialog,
                                icon: const Icon(Icons.add_home_work, color: Colors.white,),
                                label: const Text("Create Household", style: TextStyle(color: Colors.white),),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade600,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                    horizontal: 24,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            _householdInfoCard(),
                            const SizedBox(height: 16),
                            _membersCard(),
                            const SizedBox(height: 16),
                            _adminControlCard(),
                            const SizedBox(height: 20),
                            const HouseholdVotingManager(),

                            // Leave household button
                            ElevatedButton.icon(
                              onPressed: _leaveHousehold,
                              icon: const Icon(Icons.logout, color: Colors.white,),
                              label: const Text("Leave Household", style: TextStyle(color: Colors.white),),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromARGB(255, 199, 58, 58),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 18,
                                ),
                              ),
                            ),
                          ],
                        ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

// Small dialog to choose member to transfer ownership to
class TransferOwnerDialog extends StatefulWidget {
  final List<String> members;
  final FirebaseFirestore fire;
  const TransferOwnerDialog({
    super.key,
    required this.members,
    required this.fire,
  });

  @override
  State<TransferOwnerDialog> createState() => _TransferOwnerDialogState();
}

class _TransferOwnerDialogState extends State<TransferOwnerDialog> {
  String? _selectedEmail;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Transfer Ownership"),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.members.isEmpty)
              const Text("No other members available to transfer to.")
            else
              FutureBuilder<List<Map<String, String>>>(
                future: Future.wait(
                  widget.members.map((email) async {
                    final doc = await widget.fire
                        .collection('users')
                        .doc(email)
                        .get();
                    final data = doc.data();
                    return {
                      'email': email,
                      'label': data?['username'] ?? data?['email'] ?? email,
                    };
                  }),
                ),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const SizedBox(
                      height: 80,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final list = snap.data!;
                  return DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedEmail,
                    hint: const Text("Select member"),
                    items: list.map((member) {
                      return DropdownMenuItem<String>(
                        value: member['email'],
                        child: Text(member['label']!),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedEmail = val;
                      });
                    },
                  );
                },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _selectedEmail == null
              ? null
              : () {
                  // Handle ownership transfer logic here
                  Navigator.pop(context, _selectedEmail);
                },
          child: const Text("Transfer"),
        ),
      ],
    );
  }
}
