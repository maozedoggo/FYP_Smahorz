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
    required this.country,
    required this.dob,
  });

  @override
  State<CreateAccount> createState() => CreateAccountState();
}

class CreateAccountState extends State<CreateAccount> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  bool showPassword = false;
  bool showConfirm = false;

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (usernameController.text.isEmpty ||
        passwordController.text.isEmpty ||
        confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    if (passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    try {
      // 1. Create Firebase Authentication account
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: widget.email,
        password: passwordController.text.trim(),
      );

      // 2. Save user profile in Firestore with all fields
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'uid': userCredential.user!.uid,
        'name': widget.name,
        'phone': widget.phone,
        'email': widget.email,
        'username': usernameController.text.trim(),
        'addressLine1': widget.addressLine1,
        'addressLine2': widget.addressLine2,
        'postalCode': widget.postalCode,
        'state': widget.state,
        'country': widget.country,
        'dob': widget.dob.toIso8601String(),
        'createdAt': DateTime.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created successfully!')),
      );

      // 3. Go back to Login
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Error: ${e.message}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Name: ${widget.name}'),
            Text('Phone: ${widget.phone}'),
            Text('Email: ${widget.email}'),
            Text('Address Line 1: ${widget.addressLine1}'),
            Text('Address Line 2: ${widget.addressLine2}'),
            Text('Postal Code: ${widget.postalCode}'),
            Text('State: ${widget.state}'),
            Text('Country: ${widget.country}'),
            Text('Date of Birth: ${widget.dob.toLocal().toString().split(' ')[0]}'),
            const SizedBox(height: 16),

            TextField(
              controller: usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: passwordController,
              obscureText: !showPassword,
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  icon: Icon(showPassword ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => showPassword = !showPassword),
                ),
              ),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: confirmPasswordController,
              obscureText: !showConfirm,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                suffixIcon: IconButton(
                  icon: Icon(showConfirm ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => showConfirm = !showConfirm),
                ),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _submit,
              child: const Text('Create Account'),
            ),
          ],
        ),
      ),
    );
  }
}
