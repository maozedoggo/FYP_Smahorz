// ignore_for_file: file_names, depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';  // For formatting date

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController addressLine1Controller = TextEditingController();
  final TextEditingController addressLine2Controller = TextEditingController();
  final TextEditingController postalCodeController = TextEditingController();

  String? selectedCountryCode = '+60'; // Default Malaysia country code
  String? selectedCountry;
  String? selectedState;
  DateTime? selectedDOB;

  final List<String> countryCodes = [
    '+60', // Malaysia
    '+1',  // USA
    '+44', // UK
    '+61', // Australia
    '+91', // India
    '+65', // Singapore
  ];

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

  // Name validation: only letters, min 8, max 40
  String? _validateName(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your name';
    if (value.length < 8) return 'Name must be at least 8 characters';
    if (value.length > 40) return 'Name must be less than 40 characters';
    final validName = RegExp(r'^[a-zA-Z\s]+$');
    if (!validName.hasMatch(value)) return 'Name can only contain letters and spaces';
    return null;
  }

  // Phone validation: non empty, digits only
  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your phone number';
    final validPhone = RegExp(r'^\d+$');
    if (!validPhone.hasMatch(value)) return 'Phone number can only contain digits';
    return null;
  }

  // Email validation using regex
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your email';
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) return 'Enter a valid email address';
    return null;
  }

  String? _validateAddressLine1(String? value) {
    if (value == null || value.isEmpty) return 'Please enter address line 1';
    return null;
  }

  String? _validatePostalCode(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your postal code';
    final postalRegex = RegExp(r'^\d{3,10}$');
    if (!postalRegex.hasMatch(value)) return 'Enter a valid postal code';
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

  Future<void> _pickDateOfBirth() async {
    final initialDate = DateTime.now().subtract(const Duration(days: 365 * 20)); // 20 years ago
    final newDate = await showDatePicker(
      context: context,
      initialDate: selectedDOB ?? initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (newDate != null) {
      setState(() {
        selectedDOB = newDate;
      });
    }
  }

  void _submit() {
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
      // Show errors via snackbar or form
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

    // All good, print info and show success
    print('Sign Up Info:');
    print('Name: ${nameController.text}');
    print('Phone: $selectedCountryCode ${phoneController.text}');
    print('Email: ${emailController.text}');
    print('Address Line 1: ${addressLine1Controller.text}');
    print('Address Line 2: ${addressLine2Controller.text}');
    print('State: $selectedState');
    print('Postal Code: ${postalCodeController.text}');
    print('Country: $selectedCountry');
    print('Date of Birth: ${DateFormat('yyyy-MM-dd').format(selectedDOB!)}');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sign Up Successful!')),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final dobText = selectedDOB == null ? 'Select Date of Birth' : DateFormat('yyyy-MM-dd').format(selectedDOB!);

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

            // Phone number with country code dropdown
            Row(
              children: [
                DropdownButton<String>(
                  value: selectedCountryCode,
                  items: countryCodes
                      .map((code) => DropdownMenuItem(
                            value: code,
                            child: Text(code),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedCountryCode = value;
                    });
                  },
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

            // Address Line 1
            TextFormField(
              controller: addressLine1Controller,
              decoration: const InputDecoration(labelText: 'Address Line 1'),
            ),
            const SizedBox(height: 8),

            // Address Line 2 (optional)
            TextFormField(
              controller: addressLine2Controller,
              decoration: const InputDecoration(labelText: 'Address Line 2 (Optional)'),
            ),
            const SizedBox(height: 8),

            // State dropdown (Malaysia states)
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'State'),
              value: selectedState,
              items: malaysianStates
                  .map((state) => DropdownMenuItem(
                        value: state,
                        child: Text(state),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedState = value;
                });
              },
            ),
            const SizedBox(height: 8),

            // Postal Code
            TextFormField(
              controller: postalCodeController,
              decoration: const InputDecoration(labelText: 'Postal Code'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),

            // Country dropdown (general countries list)
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Country'),
              value: selectedCountry,
              items: countries
                  .map((country) => DropdownMenuItem(
                        value: country,
                        child: Text(country),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedCountry = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // Date of Birth picker
            Row(
              children: [
                Expanded(
                  child: Text('Date of Birth: $dobText'),
                ),
                TextButton(
                  onPressed: _pickDateOfBirth,
                  child: const Text('Select'),
                ),
              ],
            ),
            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: _submit,
              child: const Text('Sign Up'),
            ),
          ],
        ),
      ),
    );
  }
}
