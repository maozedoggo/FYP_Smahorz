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
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _postalCodeController;

  @override
  void initState() {
    super.initState();
    _addressLine1Controller =
        TextEditingController(text: widget.address["addressLine1"]);
    _addressLine2Controller =
        TextEditingController(text: widget.address["addressLine2"]);
    _cityController = TextEditingController(text: widget.address["city"]);
    _stateController = TextEditingController(text: widget.address["state"]);
    _postalCodeController =
        TextEditingController(text: widget.address["postalCode"]);
  }

  @override
  void dispose() {
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  Future<void> _saveAddress() async {
    if (_formKey.currentState!.validate()) {
      String uid = FirebaseAuth.instance.currentUser!.uid;

      final newAddress = {
        "addressLine1": _addressLine1Controller.text.trim(),
        "addressLine2": _addressLine2Controller.text.trim(),
        "city": _cityController.text.trim(),
        "state": _stateController.text.trim(),
        "postalCode": _postalCodeController.text.trim(),
      };

      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update(newAddress);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Address updated successfully!")),
        );

        Navigator.pop(context, newAddress);
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error updating address: $e")));
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
                controller: _addressLine1Controller,
                validator: _required,
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
                controller: _postalCodeController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: _required,
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
