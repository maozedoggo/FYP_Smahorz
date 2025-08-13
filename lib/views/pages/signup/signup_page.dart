// ignore_for_file: file_names, depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; //FOR DATE
import 'package:smart_horizon_home/views/pages/create_account_page/create_account.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  // Controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController addressLine1Controller = TextEditingController();
  final TextEditingController addressLine2Controller = TextEditingController();
  final TextEditingController postalCodeController = TextEditingController();

  // State
  String selectedCountryCode = '+60';
  String? selectedCountry;
  String? selectedState;
  DateTime? selectedDOB;

  // Lists
  final List<String> countryCodes = ['+60', '+1', '+44', '+61', '+91', '+65'];

  final List<String> countries = [
    'Malaysia',
    'United States',
    'United Kingdom',
    'Canada',
    'Australia',
    'India',
    'Singapore',
  ];

  final List<String> malaysianStates = [
    'Johor',
    'Kedah',
    'Kelantan',
    'Melaka',
    'Negeri Sembilan',
    'Pahang',
    'Perak',
    'Perlis',
    'Pulau Pinang',
    'Sabah',
    'Sarawak',
    'Selangor',
    'Terengganu',
    'Kuala Lumpur',
    'Labuan',
    'Putrajaya',
  ];

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    addressLine1Controller.dispose();
    addressLine2Controller.dispose();
    postalCodeController.dispose();
    super.dispose();
  }

  // ===== Validation =====
  String? _validateName(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your name';
    if (value.length < 8) return 'Name must be at least 8 characters';
    if (value.length > 40) return 'Name must be less than 40 characters';
    final validName = RegExp(r'^[a-zA-Z\s]+$');
    if (!validName.hasMatch(value)) return 'Name can only contain letters and spaces';
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your phone number';
    if (!RegExp(r'^\d+$').hasMatch(value)) return 'Phone number can only contain digits';
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your email';
    if (!RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(value)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validateAddressLine1(String? value) {
    if (value == null || value.isEmpty) return 'Please enter address line 1';
    return null;
  }

  String? _validatePostalCode(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your postal code';
    if (!RegExp(r'^\d{3,10}$').hasMatch(value)) return 'Enter a valid postal code';
    return null;
  }

  String? _validateCountry(String? value) {
    if (value == null || value.isEmpty) return 'Please select your country';
    return null;
  }

  String? _validateState(String? value) {
    if (value == null || value.isEmpty) return 'Please select your state';
    return null;
  }

  String? _validateDOB(DateTime? value) {
    if (value == null) return 'Please select your date of birth';
    if (value.isAfter(DateTime.now())) return 'Date of birth cannot be in the future';
    return null;
  }

  // ===== Date Picker =====
  Future<void> _pickDateOfBirth() async {
    final initialDate = DateTime.now().subtract(const Duration(days: 365 * 20));
    final newDate = await showDatePicker(
      context: context,
      initialDate: selectedDOB ?? initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (newDate != null) setState(() => selectedDOB = newDate);
  }

  // ===== Next Action =====
  void createaccount() {
    final nameError = _validateName(nameController.text);
    final phoneError = _validatePhone(phoneController.text);
    final emailError = _validateEmail(emailController.text);
    final addrError = _validateAddressLine1(addressLine1Controller.text);
    final postalError = _validatePostalCode(postalCodeController.text);
    final countryError = _validateCountry(selectedCountry);
    final stateError = _validateState(selectedState);
    final dobError = _validateDOB(selectedDOB);

    if (nameError != null ||
        phoneError != null ||
        emailError != null ||
        addrError != null ||
        postalError != null ||
        countryError != null ||
        stateError != null ||
        dobError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nameError ??
                phoneError ??
                emailError ??
                addrError ??
                postalError ??
                countryError ??
                stateError ??
                dobError!,
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateAccount(
          name: nameController.text,
          phone: '$selectedCountryCode ${phoneController.text}',
          email: emailController.text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dobText = selectedDOB == null
        ? 'Select Date of Birth'
        : DateFormat('yyyy-MM-dd').format(selectedDOB!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
        leading: const BackButton(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Name
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              maxLength: 40,
            ),
            const SizedBox(height: 8),

            // Phone
            Row(
              children: [
                DropdownButton<String>(
                  value: selectedCountryCode,
                  items: countryCodes
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => selectedCountryCode = v ?? '+60'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Phone Number'),
                    keyboardType: TextInputType.phone,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Email
            TextFormField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 8),

            // Address 1
            TextFormField(
              controller: addressLine1Controller,
              decoration: const InputDecoration(labelText: 'Address Line 1'),
            ),
            const SizedBox(height: 8),

            // Address 2
            TextFormField(
              controller: addressLine2Controller,
              decoration: const InputDecoration(
                labelText: 'Address Line 2 (Optional)',
              ),
            ),
            const SizedBox(height: 8),

            // State
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'State'),
              value: selectedState,
              items: malaysianStates
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => selectedState = v),
            ),
            const SizedBox(height: 8),

            // Postal Code
            TextFormField(
              controller: postalCodeController,
              decoration: const InputDecoration(labelText: 'Postal Code'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),

            // Country
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Country'),
              value: selectedCountry,
              items: countries
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => selectedCountry = v),
            ),
            const SizedBox(height: 16),

            // DOB
            Row(
              children: [
                Expanded(child: Text('Date of Birth: $dobText')),
                TextButton(onPressed: _pickDateOfBirth, child: const Text('Select')),
              ],
            ),
            const SizedBox(height: 30),

            // Next
            ElevatedButton(
              onPressed: createaccount,
              child: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }
}
