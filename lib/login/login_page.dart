import 'package:flutter/material.dart';
import 'package:smart_horizon_home/signup/signup_page.dart'; // <-- correct import

class LoginPage extends StatelessWidget {
  final TextEditingController emailController = TextEditingController();
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
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              child: const Text('Login'),
              onPressed: () {
                print("Email: ${emailController.text}");
                print("Password: ${passwordController.text}");
              },
            ),
            const SizedBox(height: 10),
            TextButton(
              child: const Text("Don't have an account? Sign Up"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SignUpPage()),
                  // If you want to use the SignUpPage from SignUp_page.dart, use:
                  // MaterialPageRoute(builder: (context) => const signUp1.SignUpPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
