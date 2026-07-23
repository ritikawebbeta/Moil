// lib/modules/auth/screen/login_screen.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/strings_utils.dart';
import '../../../widgets/app_widgets.dart';
import '../controller/auth_controller.dart';

class MoilLogoPainter extends CustomPainter {
  const MoilLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Draw upper dome (semi-circle)
    final double r = size.width * 0.38;
    final center = Offset(size.width / 2, size.height * 0.4);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      3.14159,
      3.14159,
      true,
      paint,
    );

    // Devnagri text "मॉयल"
    final textPainterDev = TextPainter(
      text: const TextSpan(
        text: 'मॉयल',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainterDev.layout(minWidth: 0, maxWidth: size.width);
    textPainterDev.paint(
      canvas,
      Offset(size.width / 2 - textPainterDev.width / 2, size.height * 0.48),
    );

    // English text "MOIL"
    final textPainterEng = TextPainter(
      text: const TextSpan(
        text: 'MOIL',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainterEng.layout(minWidth: 0, maxWidth: size.width);
    textPainterEng.paint(
      canvas,
      Offset(size.width / 2 - textPainterEng.width / 2, size.height * 0.72),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _employeeIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      //RO
      // _employeeIdController.text = "283";
      // _passwordController.text = "1000225";
      // EMP1
      //  _employeeIdController.text = "422";
      // _passwordController.text = "1000317";
      // RO1
      //Raja sir
      // _employeeIdController.text = "446";
      // _passwordController.text = "ADIPT5111G2";



  _employeeIdController.text = "16194";
      _passwordController.text = "ACEPT4553B2";

      // _passwordController.text = "ACEPT4553B";

//10095222

  //  _employeeIdController.text = "283";
  //     _passwordController.text = "ACQPK5213K";




      // _employeeIdController.text = "141";
      // _passwordController.text = "ABJPV5442P2";
      //Swapnil sir
      // _employeeIdController.text = "540";
      // _passwordController.text = "BLTPM3281J";

      //B.C.N. Gautam
      //    _employeeIdController.text = "4428";
      // _passwordController.text = "AIMPG8474A";

      //Rakesh Tumane
      //    _employeeIdController.text = "16194";
      // _passwordController.text = "ACEPT4553B11";
    }
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _employeeIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthController>();
    final success = await auth.login(
      _employeeIdController.text.trim(),
      _passwordController.text.trim(),
    );
    if (success && mounted) {
      if (auth.user?.mustChangePassword == true) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => CompulsoryPasswordChangeDialog(
            onSuccess: () {
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/dashboard');
              }
            },
            onCancel: () {
              auth.logout();
            },
          ),
        );
      } else {
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: GradientBackground(
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      _buildLogo(),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: _buildLoginCard(),
                      ),
                      const SizedBox(height: 24),
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/moil_logo.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'मॉयल लिमिटेड',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'MOIL Limited',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    return GlassCard(
      padding: const EdgeInsets.all(28),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sign In',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),
            // Employee ID
            TextFormField(
              controller: _employeeIdController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: StringsUtils.employeeId,
                prefixIcon:
                    Icon(Icons.badge_outlined, color: AppColors.primary),
                hintText: 'Enter your Employee ID',
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Employee ID is required' : null,
            ),
            const SizedBox(height: 16),
            // Password
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: StringsUtils.password,
                prefixIcon: const Icon(Icons.lock_outline_rounded,
                    color: AppColors.primary),
                hintText: 'Enter your password',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Password is required' : null,
            ),
            const SizedBox(height: 8),

            const SizedBox(height: 12),
            // Error Message
            Consumer<AuthController>(
              builder: (context, auth, _) {
                if (auth.errorMessage != null) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: AppColors.error.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            auth.errorMessage!,
                            style: const TextStyle(
                                color: AppColors.error, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            // Login Button
            Consumer<AuthController>(
              builder: (context, auth, _) {
                return PrimaryButton(
                  label: StringsUtils.login,
                  icon: Icons.login_rounded,
                  isLoading: auth.status == AuthStatus.loading,
                  onPressed: _login,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return const Column(
      children: [
        Text(
          'Unable to Login? Please contact head office team on:',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 4),
        Text(
          'Email: moilnagpur@gmail.com\nContact no.: +91 89567 93981',
          style: TextStyle(
            color: AppColors.textHint,
            fontSize: 12,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          '© 2026 MOIL Limited. All rights reserved.',
          style: TextStyle(
            color: AppColors.textHint,
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
