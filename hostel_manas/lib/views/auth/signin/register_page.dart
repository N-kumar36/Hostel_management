import 'package:flutter/material.dart';
import '../../../services/api_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Controllers
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final otpCtrl = TextEditingController();
  final regNumCtrl = TextEditingController();
  final departmentCtrl = TextEditingController();
  final yearCtrl = TextEditingController();

  final List<String> departments = [
    "B.Tech", "LLB", "MA", "MSE", "MBA", "M.Tech", "PhD", "Bsc", "Msc", "BCA", "MCA", "BBA", "Others"
  ];
  final List<String> years = [
    "1st Year", "2nd Year", "3rd Year", "4th Year", "5th Year",
  ];

  // Logic States
  String? selectedHostelId;
  List<dynamic> hostels = [];
  bool fetchingHostels = true;
  final api = ApiService();
  bool otpSent = false;
  bool loading = false;
  bool _isObscure = true;

  @override
  void initState() {
    super.initState();
    _loadHostels();
  }

  @override
  void dispose() {
    // Dispose controllers to prevent memory leaks
    nameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    passCtrl.dispose();
    otpCtrl.dispose();
    regNumCtrl.dispose();
    departmentCtrl.dispose();
    yearCtrl.dispose();
    super.dispose();
  }

  void _loadHostels() async {
    final list = await api.getHostels();
    if (!mounted) return;
    setState(() {
      hostels = list;
      fetchingHostels = false;
    });
  }

  // Step 1: Send OTP
  void sendOtp() async {
    // STRICT VALIDATION: Do not proceed if form data is not filled
    if (nameCtrl.text.isEmpty ||
        emailCtrl.text.isEmpty ||
        phoneCtrl.text.isEmpty ||
        regNumCtrl.text.isEmpty ||
        departmentCtrl.text.isEmpty ||
        yearCtrl.text.isEmpty ||
        passCtrl.text.isEmpty ||
        selectedHostelId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill in all personal and academic details before requesting OTP."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => loading = true);
    
    // Expecting a Map response from ApiService to read exact backend messages
    final response = await api.sendOtp(emailCtrl.text.trim(), phoneCtrl.text.trim());

    if (!mounted) return;
    setState(() {
      loading = false;
      if (response['success'] == true) {
        otpSent = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? "OTP sent to your email"),
            backgroundColor: Colors.green,
          )
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? "Failed to send OTP. Check details."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    });
  }

  // Step 2: Final Registration
  void register() async {
    if (selectedHostelId == null || otpCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a hostel and enter OTP")),
      );
      return;
    }

    setState(() => loading = true);

    // Matches the keys in your Node.js Controller precisely
    final response = await api.register({
      "name": nameCtrl.text.trim(),
      "regNum": regNumCtrl.text.trim(),
      "department": departmentCtrl.text.trim(),
      "year": yearCtrl.text.trim(),
      "hostelId": selectedHostelId,
      "email": emailCtrl.text.trim().toLowerCase(),
      "phone": phoneCtrl.text.trim(),
      "password": passCtrl.text,
      "otp": otpCtrl.text.trim(),
    });

    if (!mounted) return;
    setState(() => loading = false);

    if (response['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Registration Successful! Please login."),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      // Shows exact error from Node.js (e.g. "Invalid OTP" or "Email is already registered")
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message'] ?? "Registration Failed."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Account"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(), // Dismiss keyboard
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            children: [
              // Personal Info Section
              _sectionTitle("Personal Information"),
              _field(nameCtrl, "Full Name", Icons.person),
              _field(
                emailCtrl,
                "Email Address",
                Icons.email,
                keyboardType: TextInputType.emailAddress,
              ),
              _field(
                phoneCtrl,
                "Phone Number",
                Icons.phone,
                keyboardType: TextInputType.phone,
              ),

              const SizedBox(height: 24),

              // Academic Section
              _sectionTitle("Academic Details"),
              fetchingHostels
                  ? const LinearProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: DropdownButtonFormField<String>(
                        decoration: _inputDecor(
                          "Select Hostel",
                          Icons.apartment,
                        ),
                        initialValue: selectedHostelId,
                        items: hostels.map((h) {
                          return DropdownMenuItem<String>(
                            value: h['_id'].toString(),
                            child: Text(h['name'].toString()),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setState(() => selectedHostelId = val),
                      ),
                    ),

              // Fixed Academic Row with proper constraints
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: DropdownButtonFormField<String>(
                        decoration: _inputDecor("Department", Icons.school),
                        initialValue: departmentCtrl.text.isEmpty
                            ? null
                            : departmentCtrl.text,
                        items: departments
                            .map(
                              (dept) => DropdownMenuItem(
                                value: dept,
                                child: Text(
                                  dept,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setState(() => departmentCtrl.text = val ?? ''),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: DropdownButtonFormField<String>(
                        decoration: _inputDecor("Year", Icons.calendar_today),
                        initialValue: yearCtrl.text.isEmpty
                            ? null
                            : yearCtrl.text,
                        items: years
                            .map(
                              (year) => DropdownMenuItem(
                                value: year,
                                child: Text(
                                  year,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setState(() => yearCtrl.text = val ?? ''),
                      ),
                    ),
                  ),
                ],
              ),

              _field(regNumCtrl, "Registration Number", Icons.how_to_reg),

              const SizedBox(height: 24),

              // Password Section
              _sectionTitle("Security"),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: TextField(
                  controller: passCtrl,
                  obscureText: _isObscure,
                  decoration: _inputDecor("Password", Icons.lock).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isObscure ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => setState(() => _isObscure = !_isObscure),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // OTP Section (conditional)
              if (otpSent) ...[
                _sectionTitle("Verification"),
                _field(
                  otpCtrl,
                  "Enter 6-Digit OTP",
                  Icons.security,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
              ],

              // Action Buttons
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: otpSent ? Colors.green : Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  onPressed: loading ? null : (otpSent ? register : sendOtp),
                  child: loading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          otpSent
                              ? "Complete Registration"
                              : "Send Verification OTP",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 12),
              if (otpSent)
                TextButton(
                  onPressed: loading
                      ? null
                      : () => setState(() => otpSent = false),
                  child: const Text("Change Details or Resend OTP"),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.deepPurple,
        ),
      ),
    );
  }

  InputDecoration _inputDecor(String label, IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: Colors.deepPurple),
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      filled: true,
      fillColor: Colors.grey[50],
    );
  }

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: c,
        keyboardType: keyboardType,
        textInputAction: TextInputAction.next,
        decoration: _inputDecor(label, icon),
      ),
    );
  }
}