import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:psms/constants/app_constants.dart';
import 'package:psms/controllers/auth_controller.dart';
import 'package:psms/utils/responsive_helper.dart';

import 'client/client_home.dart';
import 'warehouse/warehouse_home.dart';

// ─────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────

const _kInk = Color(0xFF1A1A1A);
const _kLogoAsset = 'assets/logo/logo.jpeg';

// ─────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthController _authController = Get.put(AuthController());
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _keepLoggedIn = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: context.isMobile ? _buildMobileLayout() : _buildSplitLayout(),
      ),
    );
  }

  /// Shared side-by-side layout for tablet and desktop. Tablet just gets a
  /// slightly smaller branding panel and smaller type, handled internally
  /// by the widgets below via `context.responsive`, rather than a separate
  /// near-duplicate layout method.
  Widget _buildSplitLayout() {
    final brandingFlex = context.isDesktop ? 5 : 4;
    final formFlex = context.isDesktop ? 5 : 6;

    return SizedBox(
      height: double.infinity,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: brandingFlex, child: _buildBrandingSection()),
          Expanded(flex: formFlex, child: _buildFormSection()),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildMobileBrandingSection(),
          _buildFormSection(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // BRANDING
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildBrandingSection() {
    final headlineSize = context.responsive<double>(
        mobile: 32, tablet: 36, desktop: 48);

    return Container(
      color: _kInk,
      padding: const EdgeInsets.all(48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLogoBadge(),
          const Spacer(),
          Text(
            'Secure storage,\nsimplified tracking.',
            style: TextStyle(
              color: Colors.white,
              fontSize: headlineSize,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Manage document and box storage, retrieval, and destruction '
            'workflows from one place.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 16,
              height: 1.6,
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Widget _buildMobileBrandingSection() {
    return Container(
      width: double.infinity,
      color: _kInk,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLogoBadge(compact: true),
          const SizedBox(height: 32),
          const Text(
            'Secure storage,\nsimplified tracking.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  /// Shared logo chip for both branding sections. The asset is a .jpeg, so
  /// it isn't guaranteed to have a transparent background — sitting it on
  /// a small white card keeps it legible regardless of the dark backdrop.
  Widget _buildLogoBadge({bool compact = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 6 : 8),
      ),
      child: Image.asset(
        _kLogoAsset,
        height: compact ? 22 : 28,
        fit: BoxFit.contain,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // FORM
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildFormSection() {
    final horizontalPadding =
        context.responsive<double>(mobile: 24, tablet: 48, desktop: 64);
    final titleSize =
        context.responsive<double>(mobile: 32, tablet: 36, desktop: 40);

    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: context.isMobile ? 40 : 0,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Sign in',
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w700,
                      color: _kInk,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Welcome back! Enter your details below.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),
                  _fieldLabel('Username'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _usernameController,
                    style: const TextStyle(fontSize: 15, color: _kInk),
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                    decoration: _inputDecoration(hint: 'Enter your username'),
                    validator: (value) =>
                        (value?.isEmpty ?? true) ? 'Please enter your username' : null,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _fieldLabel('Password'),
                      GestureDetector(
                        onTap: _showForgotPassword,
                        child: Text(
                          'Forgot password?',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    obscureText: _obscurePassword,
                    style: const TextStyle(fontSize: 15, color: _kInk),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _login(),
                    decoration: _inputDecoration(
                      hint: 'Password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.grey[500],
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Please enter your password';
                      if (value!.length < 6) return 'Password must be at least 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      SizedBox(
                        height: 20,
                        width: 20,
                        child: Checkbox(
                          value: _keepLoggedIn,
                          onChanged: (value) =>
                              setState(() => _keepLoggedIn = value ?? false),
                          activeColor: _kInk,
                          side: BorderSide(color: Colors.grey[400]!),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Keep me logged in',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Obx(() => _authController.isLoading.value
                      ? const Center(
                          child: CircularProgressIndicator(color: _kInk),
                        )
                      : SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kInk,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Sign in',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        )),
                  Obx(() {
                    if (_authController.errorMessage.value.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red[700], size: 18),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _authController.errorMessage.value,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.red[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 32),
                  Center(
                    child: Text.rich(
                      TextSpan(
                        text: 'Need an account? ',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        children: const [
                          TextSpan(
                            text: 'Contact your system administrator.',
                            style: TextStyle(
                              color: _kInk,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _kInk,
        ),
      );

  /// Shared field styling — both the username and password fields used to
  /// repeat this border/fill block in full; centralising it here means a
  /// future style tweak (e.g. a new focus color) only happens once.
  InputDecoration _inputDecoration({required String hint, Widget? suffixIcon}) {
    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
      filled: true,
      fillColor: Colors.grey[50],
      border: border(Colors.grey[300]!),
      enabledBorder: border(Colors.grey[300]!),
      focusedBorder: border(_kInk, 2),
      errorBorder: border(Colors.red[400]!),
      focusedErrorBorder: border(Colors.red[400]!, 2),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // ACTIONS
  // ─────────────────────────────────────────────────────────────────────

  void _login() async {
    if (_formKey.currentState!.validate()) {
      final success = await _authController.login(
        _usernameController.text.trim(),
        _passwordController.text.trim(),
      );

      if (success) {
        final role = _authController.currentUser.value?.role;
        if (role == 'client') {
          Get.offAll(() => ClientHomePage());
        } else {
          Get.offAll(() => WarehouseHomePage());
        }
      }
    }
  }

  void _showForgotPassword() {
    Get.snackbar(
      'Info',
      'Contact system administrator for password reset',
      backgroundColor: AppColors.info,
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(16),
    );
  }
}