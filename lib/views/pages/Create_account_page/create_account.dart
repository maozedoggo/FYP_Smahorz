import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_horizon_home/views/pages/login/login_page.dart';

class CreateAccount extends StatefulWidget {
  final String name;
  final String phone;
  final String email;
  final String addressLine1;
  final String addressLine2;
  final String postalCode;
  final String state;
  final String district;
  final String country;
  final DateTime dob;

  const CreateAccount({
    super.key,
    required this.name,
    required this.phone,
    required this.email,
    required this.addressLine1,
    required this.addressLine2,
    required this.postalCode,
    required this.state,
    required this.district,
    required this.country,
    required this.dob,
  });

  @override
  State<CreateAccount> createState() => CreateAccountState();
}

class CreateAccountState extends State<CreateAccount> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool showPassword = false;
  bool showConfirm = false;

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your password';
    if (value.length < 8) return 'Password must be at least 8 characters';

    final hasUppercase = RegExp(r'[A-Z]');
    final hasLowercase = RegExp(r'[a-z]');
    final hasSpecial = RegExp(r'[!@#$%^&*(),.?":{}|<>]');

    if (!hasUppercase.hasMatch(value)) {
      return 'Must contain at least 1 uppercase letter';
    }
    if (!hasLowercase.hasMatch(value)) {
      return 'Must contain at least 1 lowercase letter';
    }
    if (!hasSpecial.hasMatch(value)) {
      return 'Must contain at least 1 special character';
    }
    return null;
  }

  Future<void> _showPopup(String title, String message) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final passwordError = _validatePassword(passwordController.text);

    if (usernameController.text.isEmpty ||
        passwordController.text.isEmpty ||
        confirmPasswordController.text.isEmpty) {
      _showPopup('Error', 'Please fill all fields');
      return;
    }

    if (passwordError != null) {
      _showPopup('Error', passwordError);
      return;
    }

    if (passwordController.text != confirmPasswordController.text) {
      _showPopup('Error', 'Passwords do not match');
      return;
    }

    try {
      // Check if username already exists
      final usernameQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: usernameController.text.trim())
          .limit(1)
          .get();

      if (usernameQuery.docs.isNotEmpty) {
        _showPopup(
          'Error',
          'Username already taken, please choose another one.',
        );
        return;
      }

      // Create Firebase Authentication account
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: widget.email,
            password: passwordController.text.trim(),
          );

      // Save user profile in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.email) // use email as document ID
          .set({
            'uid': userCredential.user!.uid,
            'username': usernameController.text.trim(),
            'name': widget.name,
            'email': widget.email,
            'phone': widget.phone,
            'addressLine1': widget.addressLine1,
            'addressLine2': widget.addressLine2,
            'postalCode': widget.postalCode,
            'state': widget.state,
            'district': widget.district,
            'country': widget.country,
            'dob': widget.dob.toIso8601String(),
            'createdAt': FieldValue.serverTimestamp(),
          });

      await _showPopup('Success', 'Account created successfully!');

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        _showPopup('Error', 'This email is already registered.');
      } else {
        _showPopup('Error', e.message ?? 'Something went wrong');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      resizeToAvoidBottomInset: true, // important for keyboard
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0063a1), Color(0xFF0982BA), Color(0xFF04111C)],
            stops: [0.21, 0.41, 1.0],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                const Text(
                  "CREATE ACCOUNT",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 30),

                // User info summary
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Name: ${widget.name}"),
                        Text("Phone: ${widget.phone}"),
                        Text("Email: ${widget.email}"),
                        Text("Address Line 1: ${widget.addressLine1}"),
                        Text("Address Line 2: ${widget.addressLine2}"),
                        Text("Postal Code: ${widget.postalCode}"),
                        Text("State: ${widget.state}"),
                        Text("District: ${widget.district}"),
                        Text("Country: ${widget.country}"),
                        Text(
                          "Date of Birth: ${widget.dob.toLocal().toString().split(' ')[0]}",
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // Username & Password fields
                Container(
                  padding: const EdgeInsets.all(20),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      // Username
                      TextField(
                        controller: usernameController,
                        decoration: const InputDecoration(
                          prefixIconColor: Colors.black54,
                          prefixIcon: Icon(Icons.person),
                          hintText: "USERNAME",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Password
                      TextField(
                        controller: passwordController,
                        obscureText: !showPassword,
                        decoration: InputDecoration(
                          prefixIconColor: Colors.black54,
                          prefixIcon: const Icon(Icons.key),
                          hintText: "PASSWORD",
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              showPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () =>
                                setState(() => showPassword = !showPassword),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Confirm Password
                      TextField(
                        controller: confirmPasswordController,
                        obscureText: !showConfirm,
                        decoration: InputDecoration(
                          prefixIconColor: Colors.black54,
                          prefixIcon: const Icon(Icons.key),
                          hintText: "CONFIRM PASSWORD",
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              showConfirm
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () =>
                                setState(() => showConfirm = !showConfirm),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Create Account button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Create Account',
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                        ),
                      ),

                      // Add extra spacing for keyboard
                      SizedBox(height: screenHeight * 0.05),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
