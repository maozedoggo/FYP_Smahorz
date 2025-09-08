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

  late TextEditingController _line1Controller;
  late TextEditingController _line2Controller;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _postcodeController;

  @override
  void initState() {
    super.initState();
    _line1Controller = TextEditingController(text: widget.address["line1"]);
    _line2Controller = TextEditingController(text: widget.address["line2"]);
    _cityController = TextEditingController(text: widget.address["city"]);
    _stateController = TextEditingController(text: widget.address["state"]);
    _postcodeController = TextEditingController(text: widget.address["postcode"]);
  }

  @override
  void dispose() {
    _line1Controller.dispose();
    _line2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postcodeController.dispose();
    super.dispose();
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  Future<void> _saveAddress() async {
    if (_formKey.currentState!.validate()) {
      String uid = FirebaseAuth.instance.currentUser!.uid;

      final newAddress = {
        "line1": _line1Controller.text.trim(),
        "line2": _line2Controller.text.trim(),
        "city": _cityController.text.trim(),
        "state": _stateController.text.trim(),
        "postcode": _postcodeController.text.trim(),
      };

      try {
        // 🔹 Save address into Firestore nested "address" map
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'address': newAddress,
        });

        // 🔹 Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Address updated successfully!")),
        );

        // 🔹 Return updated address back to SettingsPage
        Navigator.pop(context, newAddress);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error updating address: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Address")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _line1Controller,
                validator: _required,
                decoration: const InputDecoration(
                  labelText: "Address Line 1",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _line2Controller,
                decoration: const InputDecoration(
                  labelText: "Address Line 2",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cityController,
                validator: _required,
                decoration: const InputDecoration(
                  labelText: "City",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _stateController,
                validator: _required,
                decoration: const InputDecoration(
                  labelText: "State",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _postcodeController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: _required,
                decoration: const InputDecoration(
                  labelText: "Postcode",
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
