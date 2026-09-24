import 'package:flutter/material.dart';

import '../../../services/api_service.dart';
import '../signin/register_page.dart';
import '../../dashbord/home_page.dart';
import '../forgetPassword/ForgetPasswordPage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController passCtrl = TextEditingController();

  final ApiService api = ApiService();

  bool loading = false;
  bool _isObscure = true;

  late AnimationController _shakeController;
  late Animation<Offset> _shakeAnimation;

  // ===========================================================================
  // APP COLORS
  // ===========================================================================

  static const Color _primary = Color(0xFF5B4FE9);
  static const Color _primaryDark = Color(0xFF4338CA);

  static const Color _background = Color(0xFFF7F8FC);
  static const Color _text = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _shakeAnimation =
        Tween<Offset>(begin: Offset.zero, end: const Offset(0.025, 0)).animate(
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

  // ===========================================================================
  // LOGIN
  // ===========================================================================

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      _shakeController.forward(from: 0).then((_) => _shakeController.reverse());

      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final response = await api.login(
        emailCtrl.text.trim().toLowerCase(),
        passCtrl.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        loading = false;
      });

      if (response['success'] == true) {
        final bool isManager =
            response['user'] != null && response['user']['role'] == 'manager';

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(isManager: isManager),
          ),
        );
      } else {
        _showError(response['message']?.toString() ?? 'Login failed');
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      _showError('Unable to connect to the server');
    }
  }

  // ===========================================================================
  // ERROR
  // ===========================================================================

  void _showError(String message) {
    _shakeController.forward(from: 0).then((_) => _shakeController.reverse());

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFE94C5F),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          // -------------------------------------------------------------------
          // SOFT BACKGROUND DECORATION
          // -------------------------------------------------------------------
          Positioned(
            top: -130,
            right: -100,
            child: _softCircle(size: 330, color: _primary),
          ),

          Positioned(
            bottom: -160,
            left: -120,
            child: _softCircle(size: 350, color: const Color(0xFF8B7FF5)),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 35),
                child: SlideTransition(
                  position: _shakeAnimation,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 450),
                    child: Column(
                      children: [
                        _buildBrand(),

                        const SizedBox(height: 30),

                        _buildLoginCard(),

                        const SizedBox(height: 22),

                        _buildFooter(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // BRAND
  // ===========================================================================

  Widget _buildBrand() {
    return Column(
      children: [
        // Logo
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_primary, _primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _primary.withOpacity(0.22),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.restaurant_rounded,
            color: Colors.white,
            size: 38,
          ),
        ),

        const SizedBox(height: 18),

        const Text(
          'HostelMess',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _text,
            fontSize: 29,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          'Your mess. Your meals. Simplified.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _muted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // LOGIN CARD
  // ===========================================================================

  Widget _buildLoginCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: const Color(0xFFE8E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF202040).withOpacity(0.06),
            blurRadius: 35,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -----------------------------------------------------------------
            // CARD HEADER
            // -----------------------------------------------------------------
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEEEFF),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.lock_person_rounded,
                    color: _primary,
                    size: 21,
                  ),
                ),

                const SizedBox(width: 11),

                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back',
                        style: TextStyle(
                          color: _text,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Sign in to continue',
                        style: TextStyle(color: _muted, fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 27),

            // -----------------------------------------------------------------
            // EMAIL
            // -----------------------------------------------------------------
            _fieldLabel('EMAIL ADDRESS'),

            const SizedBox(height: 8),

            _inputField(
              controller: emailCtrl,
              hint: 'Enter your email',
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
            ),

            const SizedBox(height: 17),

            // -----------------------------------------------------------------
            // PASSWORD
            // -----------------------------------------------------------------
            _fieldLabel('PASSWORD'),

            const SizedBox(height: 8),

            _inputField(
              controller: passCtrl,
              hint: 'Enter your password',
              icon: Icons.lock_outline_rounded,
              isPassword: true,
            ),

            // -----------------------------------------------------------------
            // FORGOT PASSWORD
            // -----------------------------------------------------------------
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ForgetPasswordPage(key: GlobalKey()),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: _primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 5,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(
                    color: _primary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 17),

            // -----------------------------------------------------------------
            // LOGIN BUTTON
            // -----------------------------------------------------------------
            _buildLoginButton(),

            const SizedBox(height: 22),

            // -----------------------------------------------------------------
            // DIVIDER
            // -----------------------------------------------------------------
            Row(
              children: [
                Expanded(
                  child: Container(height: 1, color: const Color(0xFFEDEDF2)),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(height: 1, color: const Color(0xFFEDEDF2)),
                ),
              ],
            ),

            const SizedBox(height: 19),

            // -----------------------------------------------------------------
            // REGISTER
            // -----------------------------------------------------------------
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                children: [
                  const Text(
                    'Don\'t have an account? ',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterPage()),
                      );
                    },
                    child: const Text(
                      'Create account',
                      style: TextStyle(
                        color: _primary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // INPUT FIELD
  // ===========================================================================

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool isPassword = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: isPassword ? _isObscure : false,
      textInputAction: isPassword ? TextInputAction.done : TextInputAction.next,
      style: const TextStyle(
        color: _text,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      cursorColor: _primary,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'This field is required';
        }

        if (keyboardType == TextInputType.emailAddress &&
            !value.contains('@')) {
          return 'Enter a valid email address';
        }

        return null;
      },
      onFieldSubmitted: (_) {
        if (isPassword && !loading) {
          _login();
        }
      },
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: _muted, size: 19),

        suffixIcon: isPassword
            ? IconButton(
                onPressed: () {
                  setState(() {
                    _isObscure = !_isObscure;
                  });
                },
                splashRadius: 20,
                icon: Icon(
                  _isObscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _muted,
                  size: 19,
                ),
              )
            : null,

        hintText: hint,

        hintStyle: const TextStyle(
          color: Color(0xFF9CA3AF),
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
        ),

        filled: true,

        fillColor: const Color(0xFFF8F8FC),

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 17,
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFFE7E7EF)),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: _primary, width: 1.4),
        ),

        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFFE94C5F)),
        ),

        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFFE94C5F), width: 1.3),
        ),

        errorStyle: const TextStyle(
          color: Color(0xFFE94C5F),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ===========================================================================
  // FIELD LABEL
  // ===========================================================================

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _muted,
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    );
  }

  // ===========================================================================
  // LOGIN BUTTON
  // ===========================================================================

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_primary, _primaryDark],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: _primary.withOpacity(0.22),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: loading ? null : _login,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white,
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: 9),
                    Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
        ),
      ),
    );
  }

  // ===========================================================================
  // FOOTER
  // ===========================================================================

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: Color(0xFF16A05D),
            shape: BoxShape.circle,
          ),
        ),

        const SizedBox(width: 7),

        const Text(
          'HostelMess • Secure Login',
          style: TextStyle(
            color: Color(0xFF9CA3AF),
            fontSize: 9.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // BACKGROUND CIRCLE
  // ===========================================================================

  Widget _softCircle({required double size, required Color color}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(0.10),
            color.withOpacity(0.025),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
    );
  }
}
