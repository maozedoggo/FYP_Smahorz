import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditAddressPage extends StatefulWidget {
  final Map<String, String> initialAddress;

  const EditAddressPage({super.key, required this.initialAddress});

  @override
  State<EditAddressPage> createState() => _EditAddressPageState();
}

class _EditAddressPageState extends State<EditAddressPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _addressLine1Controller;
  late TextEditingController _addressLine2Controller;
  late TextEditingController _districtController;
  late TextEditingController _stateController;
  late TextEditingController _postalCodeController;
  late TextEditingController _countryController;

  bool isLoading = true;
  DocumentReference? userDocRef;

  @override
  void initState() {
    super.initState();

    // Initialize controllers with initial data from SettingsPage
    _addressLine1Controller = TextEditingController(
      text: widget.initialAddress['addressLine1'] ?? '',
    );
    _addressLine2Controller = TextEditingController(
      text: widget.initialAddress['addressLine2'] ?? '',
    );
    _districtController = TextEditingController(
      text: widget.initialAddress['district'] ?? '',
    );
    _stateController = TextEditingController(
      text: widget.initialAddress['state'] ?? '',
    );
    _postalCodeController = TextEditingController(
      text: widget.initialAddress['postalCode'] ?? '',
    );
    _countryController = TextEditingController(
      text: widget.initialAddress['country'] ?? 'Malaysia',
    );

    _loadUserAddress();
  }

  Future<void> _loadUserAddress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      // Use email as document ID (users collection uses email as doc id)
      userDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.email);
      final snapshot = await userDocRef!.get();

      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        setState(() {
          _addressLine1Controller.text = data['addressLine1'] ?? '';
          _addressLine2Controller.text = data['addressLine2'] ?? '';
          _districtController.text = data['district'] ?? '';
          _stateController.text = data['state'] ?? '';
          _postalCodeController.text = data['postalCode'] ?? '';
          _countryController.text = data['country'] ?? 'Malaysia';
          isLoading = false;
        });

        debugPrint("=== LOADED ADDRESS FROM FIRESTORE ===");
        debugPrint("Address Line 1: ${data['addressLine1']}");
        debugPrint("District: ${data['district']}");
        debugPrint("State: ${data['state']}");
        debugPrint("Postal Code: ${data['postalCode']}");
        debugPrint("Country: ${data['country']}");
        debugPrint("=== END DEBUG ===");
      } else {
        setState(() => isLoading = false);
        debugPrint("User document not found for email: ${user.email}");
        // Don't show error - just use the initial data from SettingsPage
      }
    } catch (e) {
      setState(() => isLoading = false);
      debugPrint("Error loading address: $e");
      // Don't show error - just use the initial data from SettingsPage
    }
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;
    if (userDocRef == null) return;

    final updatedAddress = {
      "addressLine1": _addressLine1Controller.text.trim(),
      "addressLine2": _addressLine2Controller.text.trim(),
      "district": _districtController.text.trim(),
      "state": _stateController.text.trim(),
      "postalCode": _postalCodeController.text.trim(),
      "country": _countryController.text.trim(),
      "updatedAt": FieldValue.serverTimestamp(),
    };

    try {
      await userDocRef!.set(updatedAddress, SetOptions(merge: true));

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Address updated successfully!")),
      );

      // Return updated address to SettingsPage
      Navigator.pop(context, updatedAddress);
    } catch (e) {
      debugPrint("Error saving address: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error updating address: $e")));
    }
  }

  @override
  void dispose() {
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _districtController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 240, 240, 241),
      appBar: AppBar(
        title: const Text("Edit Address"),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveAddress),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _addressLine1Controller,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                      decoration: const InputDecoration(
                        labelText: "Address Line 1*",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.home),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressLine2Controller,
                      decoration: const InputDecoration(
                        labelText: "Address Line 2",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.home_work),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _districtController,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                      decoration: const InputDecoration(
                        labelText: "District / City*",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_city),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _stateController,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                      decoration: const InputDecoration(
                        labelText: "State*",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.map),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _postalCodeController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                      decoration: const InputDecoration(
                        labelText: "Postal Code*",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.markunread_mailbox),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _countryController,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                      decoration: const InputDecoration(
                        labelText: "Country*",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.public),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveAddress,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.all(16),
                        ),
                        child: const Text(
                          "Save Changes",
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
