import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:psms/constants/app_constants.dart';
import 'package:psms/controllers/auth_controller.dart';
import 'package:psms/utils/responsive_helper.dart';

import 'client/client_home.dart';
import 'warehouse/warehouse_home.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthController _authController = Get.put(AuthController());
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _keepLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _usernameController.text = 'admin';
    _passwordController.text = 'admin123';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: context.isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(flex: 5, child: _buildBrandingSection()),
        Expanded(flex: 5, child: _buildFormSection()),
      ],
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

  Widget _buildBrandingSection() {
    return Container(
      height: context.screenHeight,
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        image: DecorationImage(
          image: AssetImage('assets/images/background2.jpg'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.4),
            BlendMode.darken,
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.3),
              Colors.black.withOpacity(0.6),
            ],
          ),
        ),
        padding: EdgeInsets.all(48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inventory_2_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'DOCSECURE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            Spacer(),
            Text(
              'Build something\namazing today.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Streamline your document storage and retrieval\nprocesses with our comprehensive system.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 16,
                height: 1.6,
              ),
            ),
            Spacer(flex: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileBrandingSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
      ),
      padding: EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inventory_2_rounded, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text(
                  'DOCSECURE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 32),
          Text(
            'Build something\namazing today.',
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

  Widget _buildFormSection() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: context.isMobile ? 24 : 64,
        vertical: context.isMobile ? 40 : 0,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 440),
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
                      fontSize: context.isMobile ? 32 : 40,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Welcome back! Enter your details below.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 40),
                  Text(
                    'Email address',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  SizedBox(height: 8),
                  TextFormField(
                    controller: _usernameController,
                    style: TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)),
                    decoration: InputDecoration(
                      hintText: 'Your email address',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Color(0xFF1A1A1A), width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.red[400]!),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.red[400]!, width: 2),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Please enter your email';
                      return null;
                    },
                  ),
                  SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Password',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
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
                  SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)),
                    decoration: InputDecoration(
                      hintText: 'Password',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Color(0xFF1A1A1A), width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.red[400]!),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.red[400]!, width: 2),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: Colors.grey[500],
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Please enter your password';
                      if (value!.length < 6) return 'Password must be at least 6 characters';
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      SizedBox(
                        height: 20,
                        width: 20,
                        child: Checkbox(
                          value: _keepLoggedIn,
                          onChanged: (value) => setState(() => _keepLoggedIn = value ?? false),
                          activeColor: Color(0xFF1A1A1A),
                          side: BorderSide(color: Colors.grey[400]!),
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Keep me logged in',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  Obx(() => _authController.isLoading.value
                      ? Center(
                          child: CircularProgressIndicator(color: Color(0xFF1A1A1A)),
                        )
                      : SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF1A1A1A),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
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
                    if (_authController.errorMessage.value.isEmpty) return SizedBox.shrink();
                    return Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red[700], size: 18),
                            SizedBox(width: 12),
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
                  SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey[300])),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey[300])),
                    ],
                  ),
                  SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: _buildSocialButton('GitHub', Icons.code)),
                      SizedBox(width: 12),
                      Expanded(child: _buildSocialButton('Google', Icons.g_mobiledata)),
                    ],
                  ),
                  SizedBox(height: 32),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                        GestureDetector(
                          onTap: _showSignUpInfo,
                          child: Text(
                            'Sign up',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF1A1A1A),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildSocialButton(String label, IconData icon) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Get.snackbar(
              'Info',
              '$label sign-in is not configured',
              backgroundColor: AppColors.info,
              colorText: Colors.white,
              snackPosition: SnackPosition.TOP,
              margin: EdgeInsets.all(16),
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: Color(0xFF1A1A1A)),
              SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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

  void _showSignUpInfo() {
    Get.snackbar(
      'Info',
      'Contact system administrator for account creation',
      backgroundColor: AppColors.info,
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      margin: EdgeInsets.all(16),
    );
  }

  void _showForgotPassword() {
    Get.snackbar(
      'Info',
      'Contact system administrator for password reset',
      backgroundColor: AppColors.info,
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      margin: EdgeInsets.all(16),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}