import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditAddressPage extends StatefulWidget {
  final Map<String, String> address;

  const EditAddressPage({super.key, required this.address});

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

  bool isLoading = true;
  DocumentReference? userDocRef;

  @override
  void initState() {
    super.initState();

    _addressLine1Controller = TextEditingController(
      text: widget.address['line1'],
    );
    _addressLine2Controller = TextEditingController(
      text: widget.address['line2'],
    );
    _districtController = TextEditingController(
      text: widget.address['district'],
    );
    _stateController = TextEditingController(text: widget.address['state']);
    _postalCodeController = TextEditingController(
      text: widget.address['postcode'],
    );

    _loadUserAddress();
  }

  Future<void> _loadUserAddress() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) return;

    try {
      userDocRef = FirebaseFirestore.instance.collection('users').doc(email);
      final snapshot = await userDocRef!.get();

      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        setState(() {
          _addressLine1Controller.text = data['addressLine1'] ?? '';
          _addressLine2Controller.text = data['addressLine2'] ?? '';
          _districtController.text = data['district'] ?? '';
          _stateController.text = data['state'] ?? '';
          _postalCodeController.text = data['postalCode'] ?? '';
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User document not found!")),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
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
      "country": "Malaysia",
    };

    try {
      await userDocRef!.set(updatedAddress, SetOptions(merge: true));
      Navigator.pop(context, updatedAddress); // return updated map
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error updating: $e")));
    }
  }

  @override
  void dispose() {
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _districtController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 240, 240, 241),
      appBar: AppBar(title: const Text("Edit Address")),
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
                        labelText: "Address Line 1",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressLine2Controller,
                      decoration: const InputDecoration(
                        labelText: "Address Line 2",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _districtController,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                      decoration: const InputDecoration(
                        labelText: "District / City",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _stateController,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                      decoration: const InputDecoration(
                        labelText: "State",
                        border: OutlineInputBorder(),
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
                        labelText: "Postal Code",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _saveAddress,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.all(12),
                      ),
                      child: const Text("Save Changes"),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
