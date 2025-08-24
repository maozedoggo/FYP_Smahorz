import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_horizon_home/views/pages/home_page.dart';
import 'package:smart_horizon_home/views/pages/signup/signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController loginIdController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool showPassword = false;

  @override
  void dispose() {
    loginIdController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (loginIdController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email/username & password')),
      );
      return;
    }

    String loginInput = loginIdController.text.trim();
    String password = passwordController.text.trim();
    String emailToUse = loginInput;

    try {
      // Check if input is a username (not email)
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(loginInput)) {
        // Fetch email from Firestore using username
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: loginInput)
            .get();

        if (querySnapshot.docs.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No user found with this username')),
          );
          return;
        }

        emailToUse = querySnapshot.docs.first.get('email');
      }

      // Log in with email and password
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailToUse,
        password: password,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login successful!')),
      );

      // Navigate to Home Page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );

    } on FirebaseAuthException catch (e) {
      String message = 'Login failed';
      if (e.code == 'user-not-found') {
        message = 'No user found with this email';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: loginIdController,
              decoration: const InputDecoration(labelText: 'Email or Username'),
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
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _login,
              child: const Text('Login'),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SignUpPage()),
              ),
              child: const Text('Don’t have an account? Sign Up'),
            ),
          ],
        ),
      ),
    );
  }
}
