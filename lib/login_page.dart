import 'package:flutter/material.dart';
import 'package:smart_horizon_home/views/pages/home_page.dart';

class LoginPage extends StatelessWidget {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: 'Password'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              child: Text('Login'),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => HomePage()));
                print("Email: ${emailController.text}");
                print("Password: ${passwordController.text}");
              },
            ),
            SizedBox(height: 10),
            TextButton(
              child: Text("Don't have an account? Sign Up"),
              onPressed: () {
                // TODO: Navigate to your Sign Up page here
                print("No Account? Sign Up");
              },
            ),
          ],
        ),
      ),
    );
  }
}
