import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  // ===== ActionCodeSettings for reset link =====
  ActionCodeSettings _actionCodeSettings() {
    return ActionCodeSettings(
      url: 'https://smahorz-fyp.web.app',
      handleCodeInApp: true,
      androidPackageName: 'com.example.smart_horizon_home',
      androidInstallApp: true,
      androidMinimumVersion: '21',
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

    if (emailToUse == null) {
      await _showPopup('Error', "No email found to send reset link.");
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: emailToUse,
        actionCodeSettings: _actionCodeSettings(),
      );
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
        await FirebaseAuth.instance.sendPasswordResetEmail(
          email: _emailUsed!,
          actionCodeSettings: _actionCodeSettings(),
        );
        await _showPopup('Success', "Password reset email resent!");
      } catch (e) {
        await _showPopup('Error', "Failed to resend email: ${e.toString()}");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0063a1), // #0063a1
              Color(0xFF0982BA), // rgba(9, 130, 186, 1)
              Color(0xFF04111C), // rgba(4, 17, 28, 1)
            ],
            stops: [0.21, 0.41, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Back Button
                Align(
                  alignment: Alignment.topLeft,
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withAlpha(20),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Title with shadow
                const Text(
                  "FORGOT PASSWORD",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        offset: Offset(2, 2),
                        blurRadius: 4,
                        color: Colors.black54,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Main White Container
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Enter your email or username to reset your password.",
                        style: TextStyle(fontSize: 16, color: Colors.black87),
                      ),
                      const SizedBox(height: 20),

                      // Input Field
                      TextField(
                        controller: _userController,
                        style: const TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          hintText: "Email or Username",
                          hintStyle: const TextStyle(color: Colors.black54),
                          filled: true,
                          fillColor: Colors.black.withAlpha(20),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Colors.black,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Colors.black,
                              width: 1.5,
                            ),
                          ),
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
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            "Request Password Reset",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      // Resend email button
                      if (_emailSent)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _resendEmail,
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                side: const BorderSide(color: Colors.black54),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                "Resend Email",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ),
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
