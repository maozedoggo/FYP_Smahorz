import 'package:flutter/material.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _userController = TextEditingController();

  @override
  void dispose() {
    _userController.dispose();
    super.dispose();
  }

  void _requestReset() {
    String input = _userController.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your email or username")),
      );
      return;
    }
    // TODO: Implement password reset logic here
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Password reset request sent (not implemented)")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Forgot Password'),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Enter your email or username to reset your password.",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _userController,
              decoration: const InputDecoration(
                labelText: "Email or Username",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _requestReset,
                child: const Text("Request"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}