import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../auth/presentation/auth_providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _currentStep = 0;
  bool _isLoading = false;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _branchCtrl = TextEditingController(text: 'Main Branch');
  String _currency = 'USD';
  String _timezone = 'America/New_York';
  int _tableCount = 6;

  final _currencies = ['USD', 'EUR', 'GBP', 'AED', 'INR', 'SAR', 'BDT'];
  final _timezones = [
    'America/New_York', 'America/Los_Angeles', 'Europe/London',
    'Europe/Paris', 'Asia/Dubai', 'Asia/Dhaka', 'Asia/Kolkata',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose();
    _emailCtrl.dispose(); _addressCtrl.dispose(); _branchCtrl.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    setState(() => _isLoading = true);
    final data = {
      'name': _nameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'currency': _currency,
      'timezone': _timezone,
      'branch_name': _branchCtrl.text.trim(),
      'initial_categories': ['Starters', 'Mains', 'Desserts', 'Beverages'],
      'initial_tables': _tableCount,
    };
    final success = await ref.read(authProvider.notifier).completeOnboarding(data);
    if (mounted) setState(() => _isLoading = false);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save. Please try again.'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = [
      _StepContent(title: 'Restaurant Profile', content: _buildStep1()),
      _StepContent(title: 'Branch & Tables', content: _buildStep2()),
      _StepContent(title: 'Regional Settings', content: _buildStep3()),
    ];

    return Scaffold(
      body: Row(
        children: [
          // Left: Step indicator panel
          if (MediaQuery.of(context).size.width > 700)
            Container(
              width: 280,
              color: AppTheme.primaryDark,
              padding: const EdgeInsets.all(40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Row(children: [
                    Icon(Icons.restaurant, color: AppTheme.primaryGold, size: 28),
                    const SizedBox(width: 10),
                    const Text('RESTROFLOW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  ]),
                  const SizedBox(height: 60),
                  const Text('Setup Wizard', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Let\'s get your restaurant ready in a few steps.', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14, height: 1.5)),
                  const SizedBox(height: 40),
                  ...List.generate(steps.length, (i) {
                    final isDone = i < _currentStep;
                    final isCurrent = i == _currentStep;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Row(children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDone ? AppTheme.primaryGold : (isCurrent ? AppTheme.primaryGold.withOpacity(0.2) : Colors.transparent),
                            border: Border.all(color: isDone || isCurrent ? AppTheme.primaryGold : Colors.white.withOpacity(0.2)),
                          ),
                          child: Center(child: isDone
                              ? const Icon(Icons.check, size: 16, color: Colors.black)
                              : Text('${i + 1}', style: TextStyle(color: isCurrent ? AppTheme.primaryGold : Colors.white.withOpacity(0.4), fontWeight: FontWeight.bold, fontSize: 13))),
                        ),
                        const SizedBox(width: 14),
                        Text(steps[i].title, style: TextStyle(
                          color: isCurrent ? Colors.white : Colors.white.withOpacity(0.4),
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        )),
                      ]),
                    );
                  }),
                ],
              ),
            ),
          // Right: Step content
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Step ${_currentStep + 1} of ${steps.length}', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      Text(steps[_currentStep].title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 32),
                      steps[_currentStep].content,
                      const SizedBox(height: 40),
                      Row(children: [
                        if (_currentStep > 0)
                          AppButton(text: 'Back', isSecondary: true, onPressed: () => setState(() => _currentStep--)),
                        if (_currentStep > 0) const SizedBox(width: 16),
                        Expanded(child: SizedBox(height: 52, child: AppButton(
                          text: _currentStep == steps.length - 1 ? 'Launch RestroFlow 🚀' : 'Continue',
                          isLoading: _isLoading,
                          onPressed: _currentStep == steps.length - 1 ? _complete : () => setState(() => _currentStep++),
                        ))),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() => Column(children: [
    AppTextField(label: 'Restaurant Name *', hintText: 'Gourmet Bistro', controller: _nameCtrl, prefixIcon: Icons.store),
    const SizedBox(height: 20),
    AppTextField(label: 'Phone Number', hintText: '+1 (555) 123-4567', controller: _phoneCtrl, prefixIcon: Icons.phone),
    const SizedBox(height: 20),
    AppTextField(label: 'Email', hintText: 'info@restaurant.com', controller: _emailCtrl, prefixIcon: Icons.email_outlined),
    const SizedBox(height: 20),
    AppTextField(label: 'Address', hintText: '123 Main Street, City', controller: _addressCtrl, prefixIcon: Icons.location_on_outlined, maxLines: 2),
  ]);

  Widget _buildStep2() => Column(children: [
    AppTextField(label: 'First Branch Name', hintText: 'Main Branch', controller: _branchCtrl, prefixIcon: Icons.business),
    const SizedBox(height: 24),
    Text('Initial Number of Tables', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[600])),
    const SizedBox(height: 12),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      const Text('Tables to create:', style: TextStyle(fontSize: 15)),
      Row(children: [
        IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () { if (_tableCount > 1) setState(() => _tableCount--); }),
        Text('$_tableCount', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () { if (_tableCount < 30) setState(() => _tableCount++); }),
      ]),
    ]),
  ]);

  Widget _buildStep3() => Column(children: [
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Currency', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[600])),
      const SizedBox(height: 6),
      DropdownButtonFormField<String>(
        value: _currency,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        ),
        items: _currencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
        onChanged: (v) => setState(() => _currency = v!),
      ),
    ]),
    const SizedBox(height: 20),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Timezone', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[600])),
      const SizedBox(height: 6),
      DropdownButtonFormField<String>(
        value: _timezone,
        isExpanded: true,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        ),
        items: _timezones.map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (v) => setState(() => _timezone = v!),
      ),
    ]),
  ]);
}

class _StepContent {
  final String title;
  final Widget content;
  _StepContent({required this.title, required this.content});
}
