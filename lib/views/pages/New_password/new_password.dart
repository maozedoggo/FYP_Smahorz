import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_horizon_home/views/pages/login/login_page.dart';

class NewPasswordPage extends StatefulWidget {
  final String oobCode; // Required to confirm password reset

  const NewPasswordPage({super.key, required this.oobCode});

  @override
  State<NewPasswordPage> createState() => _NewPasswordPageState();
}

class _NewPasswordPageState extends State<NewPasswordPage> {
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmController = TextEditingController();
  bool showPassword = false;
  bool showConfirm = false;
  bool isLoading = false;

  @override
  void dispose() {
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  // ===== Password Validation =====
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your password';
    if (value.length < 8) return 'Password must be at least 8 characters';

    final hasUppercase = RegExp(r'[A-Z]');
    final hasLowercase = RegExp(r'[a-z]');
    final hasSpecial = RegExp(r'[!@#$%^&*(),.?":{}|<>]');

    if (!hasUppercase.hasMatch(value))
      return 'Must contain at least 1 uppercase letter';
    if (!hasLowercase.hasMatch(value))
      return 'Must contain at least 1 lowercase letter';
    if (!hasSpecial.hasMatch(value))
      return 'Must contain at least 1 special character';

    return null;
  }

  // ===== Show Popup =====
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

  // ===== Submit New Password =====
  Future<void> _submit() async {
    final passwordError = _validatePassword(passwordController.text);

    if (passwordController.text.isEmpty || confirmController.text.isEmpty) {
      await _showPopup('Error', 'Please fill all fields');
      return;
    }

    if (passwordError != null) {
      await _showPopup('Error', passwordError);
      return;
    }

    if (passwordController.text != confirmController.text) {
      await _showPopup('Error', 'Passwords do not match');
      return;
    }

    setState(() => isLoading = true);

    try {
      await FirebaseAuth.instance.confirmPasswordReset(
        code: widget.oobCode,
        newPassword: passwordController.text.trim(),
      );

      setState(() => isLoading = false);
      await _showPopup('Success', 'Password has been reset successfully!');

      if (!mounted) return;
      // Redirect to Login Page
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      setState(() => isLoading = false);
      await _showPopup('Error', e.message ?? 'Failed to reset password');
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
                "RESET PASSWORD",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),

              // Instruction
              const Text(
                "Enter your new password below.",
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 30),

              // New Password
              TextField(
                controller: passwordController,
                obscureText: !showPassword,
                decoration: InputDecoration(
                  labelText: "New Password",
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      showPassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => showPassword = !showPassword),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Confirm Password
              TextField(
                controller: confirmController,
                obscureText: !showConfirm,
                decoration: InputDecoration(
                  labelText: "Confirm Password",
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      showConfirm ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => showConfirm = !showConfirm),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Reset Password",
                          style: TextStyle(
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
