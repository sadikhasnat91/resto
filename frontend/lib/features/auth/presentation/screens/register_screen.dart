import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/theme.dart';
import '../auth_providers.dart';
import '../../../../core/widgets/design_system.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _restaurantCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose(); _passCtrl.dispose();
    _nameCtrl.dispose(); _restaurantCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final success = await ref.read(authProvider.notifier).register(
      _emailCtrl.text.trim(), _passCtrl.text,
      _nameCtrl.text.trim(), _restaurantCtrl.text.trim(),
    );
    if (mounted) setState(() => _isLoading = false);
    if (!success && mounted) {
      final err = ref.read(authProvider).errorMessage ?? 'Registration failed.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.red[700]),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Icon(Icons.restaurant, color: AppTheme.primaryGold, size: 28),
                    const SizedBox(width: 10),
                    const Text('RESTROFLOW', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  ]),
                  const SizedBox(height: 40),
                  const Text('Create your account', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Start your free trial — no credit card required.', style: TextStyle(color: Colors.grey[500])),
                  const SizedBox(height: 40),
                  Row(children: [
                    Expanded(child: AppTextField(
                      label: 'Your Name', hintText: 'Sarah Jenkins',
                      controller: _nameCtrl, prefixIcon: Icons.person_outline,
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    )),
                    const SizedBox(width: 16),
                    Expanded(child: AppTextField(
                      label: 'Restaurant Name', hintText: 'Gourmet Bistro',
                      controller: _restaurantCtrl, prefixIcon: Icons.store_outlined,
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    )),
                  ]),
                  const SizedBox(height: 20),
                  AppTextField(
                    label: 'Email', hintText: 'you@restaurant.com',
                    controller: _emailCtrl, prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                  ),
                  const SizedBox(height: 20),
                  AppTextField(
                    label: 'Password', hintText: 'Min. 8 characters',
                    controller: _passCtrl, obscureText: _obscurePass,
                    prefixIcon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility, size: 20),
                      onPressed: () => setState(() => _obscurePass = !_obscurePass),
                    ),
                    validator: (v) => (v == null || v.length < 8) ? 'Min. 8 characters required' : null,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(height: 52, child: AppButton(text: 'Create Account', onPressed: _register, isLoading: _isLoading)),
                  const SizedBox(height: 24),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('Already have an account?', style: TextStyle(color: Colors.grey[500])),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Sign in', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
