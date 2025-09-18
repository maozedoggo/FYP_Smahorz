import 'package:flutter/material.dart';
import 'views/pages/login/login_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: const AppBackground(
        child: LoginPage(), // Start with login page
      ),
    );
  }
}

// Gradient
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [
            Color.fromARGB(255, 0, 110, 179),
            Color.fromARGB(255, 66, 167, 255),
            Color.fromARGB(255, 0, 33, 61),
          ],
          stops: [0.21, 0.41, 1.0],
        ),
      ),
      child: child, // All your pages (Scaffolds) will sit on top of this
    );
  }
}
