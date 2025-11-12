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
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
      debugPrint("Error loading address: $e");
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Address updated successfully!")),
      );

      Navigator.pop(context, updatedAddress);
    } catch (e) {
      debugPrint("Error saving address: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error updating address: $e")));
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: Colors.white70),
      filled: true,
      fillColor: const Color(0xFF1E293B),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(
        backgroundColor: const Color(0xFF07101A),
        title: const Text(
          "Edit Address",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.white),
            onPressed: _saveAddress,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
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
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                        "Address Line 1*",
                        Icons.home,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _addressLine2Controller,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                        "Address Line 2",
                        Icons.home_work,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _districtController,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                        "District / City*",
                        Icons.location_city,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _stateController,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration("State*", Icons.map),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _postalCodeController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                        "Postal Code*",
                        Icons.markunread_mailbox,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _countryController,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration("Country*", Icons.public),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveAddress,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 6,
                        ),
                        child: const Text(
                          "Save Changes",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
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
