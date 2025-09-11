import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_horizon_home/views/pages/login/login_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _userController = TextEditingController();
  bool _emailSent = false;
  String? _emailUsed;

  @override
  void dispose() {
    _userController.dispose();
    super.dispose();
  }

  // ===== Show pop-up dialog =====
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

  // ===== Request password reset =====
  Future<void> _requestReset() async {
    String input = _userController.text.trim();
    if (input.isEmpty) {
      await _showPopup('Error', "Please enter your email or username");
      return;
    }

    String? emailToUse;

    if (RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(input)) {
      emailToUse = input;
    } else {
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: input)
            .get();

        if (querySnapshot.docs.isEmpty) {
          await _showPopup('Error', "No user found with this username");
          return;
        }

        emailToUse = querySnapshot.docs.first.get('email');
      } catch (e) {
        await _showPopup('Error', "Error: ${e.toString()}");
        return;
      }
    }

    try {
      if (emailToUse == null) {
        await _showPopup('Error', "No email found to send reset link.");
        return;
      }
      await FirebaseAuth.instance.sendPasswordResetEmail(email: emailToUse);
      setState(() {
        _emailSent = true;
        _emailUsed = emailToUse;
      });
      await _showPopup('Success', "Password reset email sent!");
    } on FirebaseAuthException catch (e) {
      String message = "Failed to send reset email";
      if (e.code == 'user-not-found') {
        message = "No user found with this email";
      }
      await _showPopup('Error', message);
    }
  }

  // ===== Resend email function =====
  Future<void> _resendEmail() async {
    if (_emailUsed != null) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: _emailUsed!);
        await _showPopup('Success', "Password reset email resent!");
      } catch (e) {
        await _showPopup('Error', "Failed to resend email: ${e.toString()}");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Top Back Button
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                "FORGOT PASSWORD",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),

              // Instruction
              const Text(
                "Enter your email or username to reset your password.",
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 30),

              // Email / Username input
              TextField(
                controller: _userController,
                decoration: const InputDecoration(
                  labelText: "Email or Username",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 30),

              // Request reset button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _requestReset,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "Request Password Reset",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              // Resend email button (plain white)
              if (_emailSent)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _resendEmail,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.white, // White button
                        foregroundColor: Colors.black, // Text color
                        side: const BorderSide(color: Colors.grey), // Optional subtle border
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0, // Flat look
                      ),
                      child: const Text(
                        "Resend Email",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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
