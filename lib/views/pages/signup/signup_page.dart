import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For Date
import 'package:smart_horizon_home/views/pages/create_account_page/create_account.dart';
import 'package:smart_horizon_home/views/pages/login/login_page.dart';

// ===== Districts for each state =====
final Map<String, List<String>> districtsByState = {
  "Johor": ["Batu Pahat", "Johor Bahru", "Kluang", "Kota Tinggi", "Mersing", "Muar", "Pontian", "Segamat", "Tangkak", "Kulai"],
  "Kedah": ["Baling", "Bandar Baharu", "Kota Setar", "Kuala Muda", "Kubang Pasu", "Kulim", "Langkawi", "Padang Terap", "Pendang", "Pokok Sena", "Sik", "Yan"],
  "Kelantan": ["Bachok", "Gua Musang", "Jeli", "Kota Bharu", "Kuala Krai", "Machang", "Pasir Mas", "Pasir Puteh", "Tanah Merah", "Tumpat"],
  "Melaka": ["Alor Gajah", "Jasin", "Melaka Tengah"],
  "Negeri Sembilan": ["Jelebu", "Jempol", "Kuala Pilah", "Port Dickson", "Rembau", "Seremban", "Tampin"],
  "Pahang": ["Bentong", "Bera", "Cameron Highlands", "Jerantut", "Kuantan", "Lipis", "Maran", "Pekan", "Raub", "Rompin", "Temerloh"],
  "Pulau Pinang": ["Barat Daya", "Seberang Perai Selatan", "Seberang Perai Tengah", "Seberang Perai Utara", "Timur Laut"],
  "Perak": ["Bagan Datuk", "Batang Padang", "Hilir Perak", "Hulu Perak", "Kampar", "Kerian", "Kinta", "Kuala Kangsar", "Larut Matang",  "Selama", "Manjung", "Muallim", "Perak Tengah"],
  "Perlis": ["Kangar", "Padang Besar", "Arau"],
  "Sabah": ["Beaufort", "Beluran", "Keningau", "Kota Belud", "Kota Kinabalu", "Kota Marudu", "Kuala Penyu", "Kudat", "Kunak", "Lahad Datu", "Nabawan", "Papar", "Penampang", "Pitas", "Ranau", "Sandakan", "Semporna", "Sipitang", "Tambunan", "Tawau", "Tenom", "Tongod", "Tuaran"],
  "Sarawak": ["Betong", "Bintulu", "Kapit", "Kuching", "Limbang", "Miri", "Mukah", "Samarahan", "Sarikei", "Serian", "Sibu", "Sri Aman"],
  "Selangor": ["Gombak", "Hulu Langat", "Hulu Selangor", "Klang", "Kuala Langat", "Kuala Selangor", "Petaling", "Sabak Bernam", "Sepang", "Kajang", "Bangi"],
  "Terengganu": ["Besut", "Dungun", "Hulu Terengganu", "Kemaman", "Kuala Terengganu", "Marang", "Setiu"],
  "Kuala Lumpur": ["Bukit Bintang", "Titiwangsa", "Setiawangsa", "Kepong", "Seputeh", "Cheras", "Bandar Tun Razak", "Wangsa Maju", "Lembah Pantai"],
  "Labuan": ["Labuan"],
  "Putrajaya": ["Presint 1","Presint 2", "Presint 1", "Presint 3", "Presint 4", "Presint 5", "Presint 6", "Presint 7", "Presint 8", "Presint 9", "Presint 10", "Presint 11", "Presint 12", "Presint 13", "Presint 14", "Presint 15", "Presint 16", "Presint 17", "Presint 18", "Presint 19", "Presint 20"],
};

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
  final TextEditingController countryController = TextEditingController();

  // State
  String selectedCountryCode = '+60';
  String? selectedCountry;
  String? selectedState;
  String? selectedDistrict;
  DateTime? selectedDOB;

  // Lists
  final List<String> countryCodes = ['+60', '+1', '+44', '+61', '+91', '+65'];

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
    countryController.dispose();
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
    if (value == null || value.isEmpty) return 'Please enter your country';
    return null;
  }

  String? _validateState(String? value) {
    if (value == null || value.isEmpty) return 'Please select your state';
    return null;
  }

  String? _validateDistrict(String? value) {
    if (value == null || value.isEmpty) return 'Please select your district';
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
    final countryError = _validateCountry(countryController.text);
    final stateError = _validateState(selectedState);
    final districtError = _validateDistrict(selectedDistrict);
    final dobError = _validateDOB(selectedDOB);

    if (nameError != null ||
        phoneError != null ||
        emailError != null ||
        addrError != null ||
        postalError != null ||
        countryError != null ||
        stateError != null ||
        districtError != null ||
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
                districtError ??
                dobError!,
          ),
        ),
      );
      return;
    }

    selectedCountry = countryController.text;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateAccount(
          name: nameController.text,
          phone: '$selectedCountryCode ${phoneController.text}',
          email: emailController.text,
          addressLine1: addressLine1Controller.text,
          addressLine2: addressLine2Controller.text,
          postalCode: postalCodeController.text,
          state: selectedState!,
          district: selectedDistrict!, // ✅ FIXED: force non-null
          country: selectedCountry!,
          dob: selectedDOB!,
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
            );
          },
        ),
        title: const Text('', style: TextStyle(color: Colors.black)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              const Text(
                "SIGN UP",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),

              // Name
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("NAME", style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  hintText: "Full Name",
                  border: OutlineInputBorder(),
                ),
                maxLength: 40,
              ),
              const SizedBox(height: 16),

              // Phone
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("PHONE", style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  DropdownButton<String>(
                    value: selectedCountryCode,
                    items: countryCodes
                        .map((c) => DropdownMenuItem<String>(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => selectedCountryCode = v ?? '+60'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(
                        hintText: "Phone Number",
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Email
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("EMAIL", style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  hintText: "Email Address",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // Address Line 1
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("ADDRESS LINE 1", style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: addressLine1Controller,
                decoration: const InputDecoration(
                  hintText: "Address Line 1",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Address Line 2
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("ADDRESS LINE 2 (OPTIONAL)", style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: addressLine2Controller,
                decoration: const InputDecoration(
                  hintText: "Address Line 2",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // State
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("STATE", style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "Select State",
                ),
                value: selectedState,
                items: malaysianStates
                    .map<DropdownMenuItem<String>>(
                      (s) => DropdownMenuItem<String>(
                        value: s,
                        child: Text(s),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    selectedState = v;
                    selectedDistrict = null; // reset district
                  });
                },
              ),
              const SizedBox(height: 16),

              // District
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("DISTRICT", style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "Select District",
                ),
                value: selectedDistrict,
                items: (selectedState == null
                        ? <String>[]
                        : districtsByState[selectedState] ?? <String>[])
                    .map<DropdownMenuItem<String>>(
                      (d) => DropdownMenuItem<String>(
                        value: d,
                        child: Text(d),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => selectedDistrict = v),
              ),
              const SizedBox(height: 16),

              // Postal Code
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("POSTAL CODE", style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: postalCodeController,
                decoration: const InputDecoration(
                  hintText: "Postal Code",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // Country
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("COUNTRY", style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: countryController,
                decoration: const InputDecoration(
                  hintText: "Country",
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => selectedCountry = value),
              ),
              const SizedBox(height: 16),

              // DOB
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("DATE OF BIRTH", style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: Text(dobText)),
                  TextButton(onPressed: _pickDateOfBirth, child: const Text('Select')),
                ],
              ),

              const SizedBox(height: 30),

              // Next Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: createaccount,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Next',
                    style: TextStyle(fontSize: 16, color: Colors.white),
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
