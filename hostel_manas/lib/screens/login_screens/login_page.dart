import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'register_page.dart';
import '../home_page.dart';
import 'ForgetPasswordPage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final api = ApiService();

  bool loading = false;
  bool _isObscure = true;
  late AnimationController _shakeController;
  late Animation<Offset> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation =
        Tween<Offset>(begin: Offset.zero, end: const Offset(0.02, 0)).animate(
          CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
        );
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      _shakeController.forward(from: 0).then((_) => _shakeController.reverse());
      return;
    }

    setState(() => loading = true);

    try {
      // Changed 'userData' to 'response' to better reflect what we get back
      final response = await api.login(
        emailCtrl.text.trim().toLowerCase(),
        passCtrl.text.trim(),
      );

      if (!mounted) return;
      setState(() => loading = false);

      // Check the 'success' boolean from your backend JSON
      if (response['success'] == true) {
        final bool isManager = response['user']['role'] == 'manager';
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(isManager: isManager),
          ),
        );
      } else {
        // This triggers if backend sends success: false
        _shakeController
            .forward(from: 0)
            .then((_) => _shakeController.reverse());

        // Show the specific error message (e.g., "Invalid email" or "Invalid password")
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? "Login failed"),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // This catch block handles severe app crashes, not backend 401s
      if (!mounted) return;
      setState(() => loading = false);
      _shakeController.forward(from: 0).then((_) => _shakeController.reverse());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("An unexpected error occurred"),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF6A11CB),
              Color(0xFF2575FC),
            ], // Slightly modern gradient
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SlideTransition(
                position: _shakeAnimation,
                child: Card(
                  elevation: 12,
                  shadowColor: Colors.black45,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 40,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircleAvatar(
                            radius: 40,
                            backgroundColor: Color(0xFFF3E5F5),
                            child: Icon(
                              Icons.hotel_rounded,
                              size: 45,
                              color: Colors.deepPurple,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Welcome Back",
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF311B92),
                              letterSpacing: 1,
                            ),
                          ),
                          const Text(
                            "Sign in to manage your mess",
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                          const SizedBox(height: 32),
                          _inputField(
                            emailCtrl,
                            "Email Address",
                            Icons.email_outlined,
                            type: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 20),
                          _inputField(
                            passCtrl,
                            "Password",
                            Icons.lock_outline_rounded,
                            isPassword: true,
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ForgetPasswordPage(key: GlobalKey()),
                                  ),
                                );
                              },
                              child: const Text(
                                "Forgot Password?",
                                style: TextStyle(
                                  color: Colors.deepPurple,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: loading ? null : _login,
                              child: loading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      "Sign In",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Don't have an account?"),
                              TextButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const RegisterPage(),
                                  ),
                                ),
                                child: const Text(
                                  "Create Account",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextInputType? type,
    bool isPassword = false,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      obscureText: isPassword ? _isObscure : false,
      style: const TextStyle(fontWeight: FontWeight.w500),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Required';
        if (type == TextInputType.emailAddress && !value.contains('@')) {
          return 'Invalid Email';
        }
        return null;
      },
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.black87, size: 22),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _isObscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.black54,
                ),
                onPressed: () => setState(() => _isObscure = !_isObscure),
              )
            : null,
        hintText: hint,
        hintStyle: const TextStyle(
          color: Colors.grey,
          fontWeight: FontWeight.normal,
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 16,
        ),
        // 1px Solid Black Border as requested
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.deepPurple, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
    );
  }
}
