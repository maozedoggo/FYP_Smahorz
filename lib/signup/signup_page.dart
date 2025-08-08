// ignore_for_file: file_names

import 'package:flutter/material.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController addressLine1Controller = TextEditingController();
  final TextEditingController addressLine2Controller = TextEditingController();
  final TextEditingController stateController = TextEditingController();
  final TextEditingController postalCodeController = TextEditingController();
  final TextEditingController ageController = TextEditingController();

  String? selectedCountry;

  final List<String> countries = [
    'Malaysia',
    'United States',
    'United Kingdom',
    'Canada',
    'Australia',
    'India',
    'Singapore',

  ];

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    addressLine1Controller.dispose();
    addressLine2Controller.dispose();
    stateController.dispose();
    postalCodeController.dispose();
    ageController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      // Here you would usually send the data to your backend or Firebase
      print('Sign Up Info:');
      print('Name: ${nameController.text}');
      print('Phone: ${phoneController.text}');
      print('Email: ${emailController.text}');
      print('Address Line 1: ${addressLine1Controller.text}');
      print('Address Line 2: ${addressLine2Controller.text}');
      print('State: ${stateController.text}');
      print('Postal Code: ${postalCodeController.text}');
      print('Country: $selectedCountry');
      print('Age: ${ageController.text}');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign Up Successful!')),
      );

      Navigator.pop(context); // Go back to login page after sign up
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
        leading: BackButton(), // Back button to go back to login page
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Name
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) => (value == null || value.isEmpty) ? 'Please enter your name' : null,
              ),
              // Phone
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
                validator: (value) => (value == null || value.isEmpty) ? 'Please enter your phone number' : null,
              ),
              // Email
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => (value == null || value.isEmpty) ? 'Please enter your email' : null,
              ),
              // Address Line 1
              TextFormField(
                controller: addressLine1Controller,
                decoration: const InputDecoration(labelText: 'Address Line 1'),
                validator: (value) => (value == null || value.isEmpty) ? 'Please enter address line 1' : null,
              ),
              // Address Line 2 (optional)
              TextFormField(
                controller: addressLine2Controller,
                decoration: const InputDecoration(labelText: 'Address Line 2 (Optional)'),
              ),
              // State
              TextFormField(
                controller: stateController,
                decoration: const InputDecoration(labelText: 'State'),
                validator: (value) => (value == null || value.isEmpty) ? 'Please enter your state' : null,
              ),
              // Postal Code
              TextFormField(
                controller: postalCodeController,
                decoration: const InputDecoration(labelText: 'Postal Code'),
                keyboardType: TextInputType.number,
                validator: (value) => (value == null || value.isEmpty) ? 'Please enter your postal code' : null,
              ),
              // Country dropdown before Age
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Country'),
                value: selectedCountry,
                items: countries
                    .map((country) => DropdownMenuItem(
                          value: country,
                          child: Text(country),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => selectedCountry = value),
                validator: (value) => value == null ? 'Please select your country' : null,
              ),
              // Age
              TextFormField(
                controller: ageController,
                decoration: const InputDecoration(labelText: 'Age'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter your age';
                  final age = int.tryParse(value);
                  if (age == null || age <= 0) return 'Enter a valid age';
                  return null;
                },
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _submit,
                child: const Text('Sign Up'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
