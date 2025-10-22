// settings_page.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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
  String? currentUid;
  DocumentReference<Map<String, dynamic>>? currentUserDocRef;
  String? householdId;
  DocumentReference<Map<String, dynamic>>? householdDocRef;
  String? userRole; // 'owner' | 'admin' | 'member' | null
  String? householdName;

  // household fields
  String householdAddressText = "";
  List<String> memberUids = [];
  List<String> adminUids = [];

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

    currentUid = user.uid;
    currentUserDocRef = _fire.collection('users').doc(currentUid);

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

      if (householdId != null) {
        householdDocRef = _fire.collection('households').doc(householdId);
        final hSnap = await householdDocRef!.get();
        if (hSnap.exists) {
          final hData = hSnap.data()!;

          // IMPROVED ADDRESS FETCHING LOGIC
          String address = "";

          // Check if address exists as a single string
          if (hData['address'] != null &&
              hData['address'].toString().isNotEmpty) {
            address = hData['address'].toString();
          }
          // If no single address field, check for structured address fields
          else if (hData['addressLine1'] != null || hData['street'] != null) {
            // Support multiple field naming conventions
            final addressLine1 = hData['addressLine1'] ?? hData['street'] ?? '';
            final addressLine2 =
                hData['addressLine2'] ?? hData['apartment'] ?? '';
            final city = hData['city'] ?? hData['district'] ?? '';
            final state = hData['state'] ?? hData['province'] ?? '';
            final postalCode = hData['postalCode'] ?? hData['zipCode'] ?? '';
            final country = hData['country'] ?? '';

            // Build address string from non-empty fields
            final addressParts =
                [addressLine1, addressLine2, city, state, postalCode, country]
                    .where((part) => part != null && part.toString().isNotEmpty)
                    .toList();

            address = addressParts.join(", ");
          }

          setState(() {
            householdName = hData['name'] ?? "";
            householdAddressText = address;
            _nameCtrl.text = householdName ?? "";
            _addressCtrl.text = householdAddressText;
            memberUids = List<String>.from(hData['members'] ?? []);
            adminUids = List<String>.from(hData['admins'] ?? []);
          });
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
            memberUids = [];
            adminUids = [];
            householdAddressText = "";
            _nameCtrl.clear();
            _addressCtrl.clear();
          });
        }
      } else {
        // not in any household
        setState(() {
          householdName = null;
          memberUids = [];
          adminUids = [];
          householdAddressText = "";
          _nameCtrl.clear();
          _addressCtrl.clear();
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
    if (currentUid == null) return;
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
        'ownerId': currentUid,
        'members': [currentUid],
        'admins': [currentUid],
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

      await householdDocRef!.set({
        'name': newName,
        'address': newAddress, // Save as single address field
        // You can also save as structured fields if needed:
        // 'addressLine1': _extractAddressPart(newAddress, 0),
        // 'city': _extractAddressPart(newAddress, 1),
        // etc.
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
    if (householdId == null || currentUid == null) return;
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
        // If user doesn't exist, still create an invite doc (optional) — we'll create invite pointing to email
        await _fire.collection('invites').add({
          'fromUid': currentUid,
          'toEmail': email,
          'householdId': householdId,
          'householdName': householdName,
          'status': 'pending',
          'sentAt': FieldValue.serverTimestamp(),
        });
        _inviteEmailCtrl.clear();
        _showInfo("Invite created (user not registered yet).");
        return;
      }

      final userDoc = query.docs.first;
      final toUid = userDoc.id;
      final userData = userDoc.data();
      if ((userData['householdId'] as String?) != null) {
        _showInfo("User already belongs to a household.");
        return;
      }

      // check existing invite
      final existing = await _fire
          .collection('invites')
          .where('toUid', isEqualTo: toUid)
          .where('householdId', isEqualTo: householdId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        _showInfo("Invite already pending for that user.");
        return;
      }

      await _fire.collection('invites').add({
        'fromUid': currentUid,
        'toUid': toUid,
        'householdId': householdId,
        'householdName': householdName,
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
  Future<void> _removeMember(String uid) async {
    if (householdDocRef == null) return;
    if (!(userRole == 'owner' || userRole == 'admin')) {
      _showInfo("Only owners or admins can remove members.");
      return;
    }
    // don't remove owner
    final hSnap = await householdDocRef!.get();
    final hData = hSnap.data()!;
    final ownerId = hData['ownerId'] as String?;
    if (uid == ownerId) {
      _showInfo("Cannot remove the owner. Transfer ownership first.");
      return;
    }

    try {
      await _fire.runTransaction((tx) async {
        final snap = await tx.get(householdDocRef!);
        final data = snap.data()!;
        final members = List<String>.from(data['members'] ?? []);
        final admins = List<String>.from(data['admins'] ?? []);
        members.remove(uid);
        admins.remove(uid);
        tx.update(householdDocRef!, {'members': members, 'admins': admins});
        final userRef = _fire.collection('users').doc(uid);
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
  Future<void> _transferOwnership(String newOwnerUid) async {
    if (householdDocRef == null) return;
    if (userRole != 'owner') {
      _showInfo("Only the owner can transfer ownership.");
      return;
    }
    if (newOwnerUid == currentUid) {
      _showInfo("You already are the owner.");
      return;
    }

    final name = await _getMemberName(newOwnerUid) ?? newOwnerUid;
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
      if (!admins.contains(newOwnerUid)) admins.add(newOwnerUid);
      // keep old owner in admins (or demote to admin)
      if (oldOwner != null && !admins.contains(oldOwner)) admins.add(oldOwner);

      await _fire.runTransaction((tx) async {
        tx.update(householdDocRef!, {'ownerId': newOwnerUid, 'admins': admins});
        // set new owner role
        tx.update(_fire.collection('users').doc(newOwnerUid), {
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
  Future<void> _demoteAdmin(String uid) async {
    if (householdDocRef == null) return;
    if (userRole != 'owner') {
      _showInfo("Only owner can demote admins.");
      return;
    }
    if (uid == currentUid) {
      _showInfo("Owner cannot demote themselves here.");
      return;
    }

    try {
      final hSnap = await householdDocRef!.get();
      final hData = hSnap.data()!;
      final admins = List<String>.from(hData['admins'] ?? []);
      admins.remove(uid);
      await householdDocRef!.update({'admins': admins});
      await _fire.collection('users').doc(uid).set({
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
      if (userRole == 'owner' && currentUid == ownerId) {
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
        for (final uid in members) {
          final uRef = _fire.collection('users').doc(uid);
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
      members.remove(currentUid);
      admins.remove(currentUid);
      await householdDocRef!.update({'members': members, 'admins': admins});
      await _fire.collection('users').doc(currentUid).update({
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

  Future<String?> _getMemberName(String uid) async {
    try {
      final snap = await _fire.collection('users').doc(uid).get();
      final data = snap.data();
      if (data == null) return null;
      return data['username'] ?? data['email'] ?? uid;
    } catch (e) {
      return null;
    }
  }

  // Helper to extract address parts if using structured fields
  String _extractAddressPart(String fullAddress, int index) {
    final parts = fullAddress.split(',');
    return index < parts.length ? parts[index].trim() : '';
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

  Widget _householdInfoCard() {
    final canEdit = _isAdmin;
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

  Widget _memberTileWidget(String uid) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _fire.collection('users').doc(uid).get(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final name = data?['username'] ?? data?['email'] ?? uid;
        final role =
            data?['role'] ?? (adminUids.contains(uid) ? 'admin' : 'member');
        final isCurrentUser = uid == currentUid;

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
                          onPressed: () => _removeMember(uid),
                          tooltip: "Remove member",
                        ),
                        // Promote / Transfer owner (only owner can transfer)
                        if (userRole == 'owner')
                          IconButton(
                            icon: const Icon(
                              Icons.manage_accounts,
                              color: Colors.orangeAccent,
                            ),
                            onPressed: () => _transferOwnership(uid),
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
                                if (!admins.contains(uid)) admins.add(uid);
                                await householdDocRef!.update({
                                  'admins': admins,
                                });
                                await _fire.collection('users').doc(uid).set({
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
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _headerRow(Icons.group, "Household Members"),
          const SizedBox(height: 12),
          Column(
            children: memberUids.map((u) => _memberTileWidget(u)).toList(),
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
                          : const Icon(Icons.send),
                      label: const Text("Send"),
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
                                    members: memberUids
                                        .where((u) => u != currentUid)
                                        .toList(),
                                    fire: _fire,
                                  ),
                                );
                                if (selected != null) {
                                  _transferOwnership(selected);
                                }
                              },
                              child: const Text("Transfer Owner"),
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
        backgroundColor: const Color(0xFF07101A),
        title: const Center(
          child: Text(
            "Household Settings",
            style: TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
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
                          householdName ?? "Settings",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // CONDITIONAL RENDERING - FIXED VERSION
                      if (householdId == null)
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: _createHouseholdDialog,
                            icon: const Icon(Icons.add_home_work),
                            label: const Text("Create Household"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 24,
                              ),
                            ),
                          ),
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
                              icon: const Icon(Icons.logout),
                              label: const Text("Leave Household"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade700,
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
  String? _selectedUid;

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
                  widget.members.map((uid) async {
                    final doc = await widget.fire
                        .collection('users')
                        .doc(uid)
                        .get();
                    final data = doc.data();
                    return {
                      'uid': uid,
                      'label': data?['username'] ?? data?['email'] ?? uid,
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
                    value: _selectedUid,
                    hint: const Text("Select member"),
                    items: list.map((member) {
                      return DropdownMenuItem<String>(
                        value: member['uid'],
                        child: Text(member['label']!),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedUid = val;
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
          onPressed: _selectedUid == null
              ? null
              : () {
                  // Handle ownership transfer logic here
                  Navigator.pop(context, _selectedUid);
                },
          child: const Text("Transfer"),
        ),
      ],
    );
  }
}
