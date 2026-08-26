import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/theme.dart';
import '../auth_providers.dart';
import '../../../../core/widgets/design_system.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final success = await ref.read(authProvider.notifier).login(
      _emailCtrl.text.trim(),
      _passCtrl.text,
    );
    if (mounted) setState(() => _isLoading = false);
    if (!success && mounted) {
      final err = ref.read(authProvider).errorMessage ?? 'Login failed.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.red[700]),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 900;

    return Scaffold(
      body: Row(
        children: [
          // Left brand panel (desktop only)
          if (isWide)
            Expanded(
              flex: 5,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1C1C1E), Color(0xFF2D2A22)],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(60.0),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Row(children: [
                        Icon(Icons.restaurant, color: AppTheme.primaryGold, size: 36),
                        const SizedBox(width: 16),
                        const Text(
                          'RESTROFLOW',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 48),
                      const Text(
                        'Run Your\nRestaurant\nSmarter.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 52,
                          fontWeight: FontWeight.bold,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'The complete operations platform for\nmodern restaurants.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 18,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 60),
                      _FeaturePill(icon: Icons.point_of_sale, text: 'Intelligent POS'),
                      const SizedBox(height: 12),
                      _FeaturePill(icon: Icons.kitchen, text: 'Live Kitchen Display'),
                      const SizedBox(height: 12),
                      _FeaturePill(icon: Icons.bar_chart, text: 'Real-time Analytics'),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Right login form
          Expanded(
            flex: 4,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!isWide) ...[
                          Row(children: [
                            Icon(Icons.restaurant, color: AppTheme.primaryGold, size: 28),
                            const SizedBox(width: 10),
                            const Text('RESTROFLOW', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                          ]),
                          const SizedBox(height: 40),
                        ],
                        const Text('Welcome back', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Sign in to your restaurant account', style: TextStyle(fontSize: 15, color: Colors.grey[500])),
                        const SizedBox(height: 40),
                        AppTextField(
                          label: 'Email address',
                          hintText: 'owner@restroflow.com',
                          controller: _emailCtrl,
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                        ),
                        const SizedBox(height: 20),
                        AppTextField(
                          label: 'Password',
                          hintText: '••••••••',
                          controller: _passCtrl,
                          obscureText: _obscurePass,
                          prefixIcon: Icons.lock_outline,
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility, size: 20),
                            onPressed: () => setState(() => _obscurePass = !_obscurePass),
                          ),
                          validator: (v) => (v == null || v.length < 6) ? 'Password must be at least 6 characters' : null,
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          height: 52,
                          child: AppButton(
                            text: 'Sign In',
                            onPressed: _login,
                            isLoading: _isLoading,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Don't have an account?", style: TextStyle(color: Colors.grey[500])),
                            TextButton(
                              onPressed: () => context.go('/register'),
                              child: const Text('Create one', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const _DemoCredentials(),
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
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeaturePill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryGold.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primaryGold, size: 20),
        ),
        const SizedBox(width: 14),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _DemoCredentials extends StatelessWidget {
  const _DemoCredentials();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryGold.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.info_outline, size: 14, color: AppTheme.primaryGold),
            const SizedBox(width: 6),
            const Text('Demo Credentials', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryGold)),
          ]),
          const SizedBox(height: 8),
          const Text('owner@restroflow.com  /  password123', style: TextStyle(fontSize: 13, fontFamily: 'monospace')),
        ],
      ),
    );
  }
}
