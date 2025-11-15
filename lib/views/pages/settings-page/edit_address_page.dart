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

    _addressLine1Controller =
        TextEditingController(text: widget.initialAddress['addressLine1'] ?? '');
    _addressLine2Controller =
        TextEditingController(text: widget.initialAddress['addressLine2'] ?? '');
    _districtController =
        TextEditingController(text: widget.initialAddress['district'] ?? '');
    _stateController =
        TextEditingController(text: widget.initialAddress['state'] ?? '');
    _postalCodeController =
        TextEditingController(text: widget.initialAddress['postalCode'] ?? '');
    _countryController =
        TextEditingController(text: widget.initialAddress['country'] ?? 'Malaysia');

    _loadUserAddress();
  }

  Future<void> _loadUserAddress() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      userDocRef = FirebaseFirestore.instance.collection('users').doc(user.email);
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

    final updatedData = {
      "addressLine1": _addressLine1Controller.text.trim(),
      "addressLine2": _addressLine2Controller.text.trim(),
      "district": _districtController.text.trim(),
      "state": _stateController.text.trim(),
      "postalCode": _postalCodeController.text.trim(),
      "country": _countryController.text.trim(),
      "updatedAt": FieldValue.serverTimestamp(),
    };

    try {
      await userDocRef!.set(updatedData, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Address updated successfully!")),
      );

      Navigator.pop(context, updatedData);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  // -------- UI COMPONENTS --------

  Widget _header(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 10, bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _card(Widget child) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }

  Widget _textField(
      {required TextEditingController controller,
      required String label,
      required IconData icon,
      bool requiredField = false,
      List<TextInputFormatter>? formatters,
      TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      validator: requiredField
          ? (v) => v == null || v.trim().isEmpty ? "Required" : null
          : null,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: const Color(0xFF0F172A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      ),
    );
  }

  // -------- PAGE UI --------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(
        leading: IconButton(onPressed: () => Navigator.of(context).pop(), icon: Icon(Icons.arrow_back_ios_new)),
        backgroundColor: const Color(0xFF07101A),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Edit Address",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _header("Address Details"),
                    _card(
                      Column(
                        children: [
                          _textField(
                            controller: _addressLine1Controller,
                            label: "Address Line 1",
                            icon: Icons.home,
                            requiredField: true,
                          ),
                          const SizedBox(height: 14),
                          _textField(
                            controller: _addressLine2Controller,
                            label: "Address Line 2",
                            icon: Icons.home_work,
                          ),
                          const SizedBox(height: 14),
                          _textField(
                            controller: _districtController,
                            label: "District / City",
                            icon: Icons.location_city,
                            requiredField: true,
                          ),
                          const SizedBox(height: 14),
                          _textField(
                            controller: _stateController,
                            label: "State",
                            icon: Icons.map,
                            requiredField: true,
                          ),
                          const SizedBox(height: 14),
                          _textField(
                            controller: _postalCodeController,
                            label: "Postal Code",
                            icon: Icons.markunread_mailbox,
                            requiredField: true,
                            keyboardType: TextInputType.number,
                            formatters: [FilteringTextInputFormatter.digitsOnly],
                          ),
                          const SizedBox(height: 14),
                          _textField(
                            controller: _countryController,
                            label: "Country",
                            icon: Icons.public,
                            requiredField: true,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 26),

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

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }
}
