import 'package:flutter/material.dart';
import 'package:smart_horizon_home/views/pages/signup/signup_page.dart';

class LoginPage extends StatelessWidget {
  final TextEditingController loginIdController = TextEditingController(); // Can be email or username
  final TextEditingController passwordController = TextEditingController();

  LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Email or Username field
            TextField(
              controller: loginIdController,
              decoration: const InputDecoration(labelText: 'Email or Username'),
            ),
            const SizedBox(height: 12),
            
            // Password field
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 20),
            
            // Login button
            ElevatedButton(
              child: const Text('Login'),
              onPressed: () {
                String loginId = loginIdController.text.trim();
                String password = passwordController.text;

                if (loginId.isEmpty || password.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please fill in all fields")),
                  );
                  return;
                }

                // For now, just print the values — replace with actual auth check
                print("Login ID (Email/Username): $loginId");
                print("Password: $password");

                // TODO: Replace with Firebase check:
                // If loginId contains "@", treat as email, else treat as username
                if (loginId.contains("@")) {
                  print("Logging in with email");
                  // check email in Firebase
                } else {
                  print("Logging in with username");
                  // check username in Firebase
                }
              },
            ),
            
            const SizedBox(height: 10),
            TextButton(
              child: const Text("Don't have an account? Sign Up"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SignUpPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
