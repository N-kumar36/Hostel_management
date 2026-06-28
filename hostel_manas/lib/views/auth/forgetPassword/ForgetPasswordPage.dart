import 'package:HostelMess/services/api_service.dart';
import 'package:flutter/material.dart';

class ForgetPasswordPage extends StatefulWidget {
  const ForgetPasswordPage({super.key});

  @override
  State<ForgetPasswordPage> createState() => _ForgetPasswordPageState();
}

class _ForgetPasswordPageState extends State<ForgetPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final api = ApiService();

  bool otpSent = false;
  bool isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  // Password validation regex
  final RegExp _passwordRegex = RegExp(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$'
  );

  void sendOtp() async {
    if (_emailController.text.trim().isEmpty) {
      _showSnackBar("Please enter your email address", Colors.red);
      return;
    }

    if (!_isValidEmail(_emailController.text.trim())) {
      _showSnackBar("Please enter a valid email address", Colors.red);
      return;
    }

    setState(() => isLoading = true);

    final success = await api.sendOtpForgetPass(_emailController.text.trim());

    setState(() => isLoading = false);

    if (success) {
      setState(() => otpSent = true);
      _showSnackBar("OTP sent to your email! Check your inbox/spam.", Colors.green);
      _otpController.clear(); // Clear OTP field for new attempt
    } else {
      _showSnackBar("Failed to send OTP. Please try again.", Colors.red);
    }
  }

  void verifyOtpAndReset() async {
    // Email validation
    if (_emailController.text.trim().isEmpty) {
      _showSnackBar("Email is required", Colors.red);
      return;
    }

    // OTP validation
    if (_otpController.text.trim().isEmpty || _otpController.text.trim().length != 6) {
      _showSnackBar("Please enter a valid 6-digit OTP", Colors.red);
      return;
    }

    // Password validation
    if (_passwordController.text.isEmpty) {
      _showSnackBar("Please enter new password", Colors.red);
      return;
    }

    if (!_passwordRegex.hasMatch(_passwordController.text)) {
      _showSnackBar(
        "Password must be 8+ chars with uppercase, lowercase, number & special char",
        Colors.red
      );
      return;
    }

    // Confirm password validation
    if (_confirmPasswordController.text.isEmpty) {
      _showSnackBar("Please confirm your password", Colors.red);
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnackBar("Passwords do not match!", Colors.red);
      return;
    }

    setState(() => isLoading = true);

    final success = await api.resetPasswordFunction(
      _emailController.text.trim(),
      _passwordController.text.trim(),
      _otpController.text.trim(),
    );

    setState(() => isLoading = false);

    if (success) {
      _showSnackBar("Password reset successfully! You can now login.", Colors.green);
      Future.delayed(const Duration(seconds: 1), () {
        Navigator.pop(context);
      });
    } else {
      _showSnackBar("Invalid OTP or expired. Please request new OTP.", Colors.red);
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _resendOtp() {
    setState(() {
      otpSent = false;
      _otpController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
    _showSnackBar("Please enter email to get new OTP", Colors.blue);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Reset Password"),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            const Icon(
              Icons.lock_reset,
              size: 80,
              color: Colors.deepPurple,
            ),
            const SizedBox(height: 16),
            const Text(
              "Reset Password",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              otpSent ? "Enter OTP & new password" : "Enter your email to get OTP",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 40),

            // Email Field - Always visible but disabled after OTP sent
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              enabled: !otpSent && !isLoading,
              decoration: InputDecoration(
                labelText: "Email Address",
                prefixIcon: const Icon(Icons.email_outlined),
                suffixIcon: otpSent ? const Icon(Icons.check_circle, color: Colors.green) : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
                ),
              ),
              onSubmitted: (_) => otpSent ? verifyOtpAndReset() : sendOtp(),
            ),
            const SizedBox(height: 20),

            // OTP and Password fields - Only after OTP sent
            if (otpSent) ...[
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: "Verification Code",
                  prefixIcon: const Icon(Icons.sms_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  counterText: "",
                ),
                onSubmitted: (_) => verifyOtpAndReset(),
              ),
              const SizedBox(height: 20),
              
              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: "New Password",
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_isPasswordVisible 
                        ? Icons.visibility 
                        : Icons.visibility_off),
                    onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onSubmitted: (_) => verifyOtpAndReset(),
              ),
              const SizedBox(height: 20),
              
              TextField(
                controller: _confirmPasswordController,
                obscureText: !_isConfirmPasswordVisible,
                decoration: InputDecoration(
                  labelText: "Confirm Password",
                  prefixIcon: const Icon(Icons.lock_clock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(_isConfirmPasswordVisible 
                        ? Icons.visibility 
                        : Icons.visibility_off),
                    onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onSubmitted: (_) => verifyOtpAndReset(),
              ),
              const SizedBox(height: 10),
              
              // Password requirements hint
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: const Text(
                  "• 8+ characters\n• 1 uppercase, 1 lowercase\n• 1 number, 1 special char",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 30),
            ],

            // Main Action Button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading ? null : (otpSent ? verifyOtpAndReset : sendOtp),
                style: ElevatedButton.styleFrom(
                  backgroundColor: otpSent ? Colors.deepPurple : Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        otpSent ? "RESET PASSWORD" : "SEND VERIFICATION OTP",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            if (otpSent) ...[
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: _resendOtp,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text("Resend OTP"),
              ),
            ],

            const SizedBox(height: 30),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "← Back to Login",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.deepPurple,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
