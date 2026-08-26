import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../core/theme/theme.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../../core/network/dio_client.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final dio = ref.read(dioClientProvider).dio;
      final res = await dio.get('/api/restaurants/me');
      setState(() { _profile = res.data as Map<String, dynamic>; _isLoading = false; });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Settings', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 28),
            LayoutBuilder(builder: (ctx, c) {
              final isWide = c.maxWidth > 800;
              return isWide
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: _ProfileSection(
                        user: user, profile: _profile, isLoading: _isLoading, onReload: _loadProfile,
                        onSave: _saveProfile,
                      )),
                      const SizedBox(width: 24),
                      Expanded(child: _DangerSection(
                        onLogout: () => _logout(),
                        onDeleteAccount: () => _deleteAccount(),
                      )),
                    ])
                  : Column(children: [
                      _ProfileSection(
                        user: user, profile: _profile, isLoading: _isLoading, onReload: _loadProfile,
                        onSave: _saveProfile,
                      ),
                      const SizedBox(height: 24),
                      _DangerSection(
                        onLogout: () => _logout(),
                        onDeleteAccount: () => _deleteAccount(),
                      ),
                    ]);
            }),
          ],
        ),
      ),
    );
  }

  Future<bool> _saveProfile(String name, String phone) async {
    return await ref.read(authProvider.notifier).updateProfile(name, phone);
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Delete Account?'),
      content: const Text('This action is permanent and cannot be undone. Are you sure?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
      ],
    ));
    if (confirm == true) {
      await ref.read(authProvider.notifier).deleteAccount();
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Sign Out?'),
      content: const Text('You will be redirected to the login page.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true), child: const Text('Sign Out')),
      ],
    ));
    if (confirm == true) {
      await ref.read(authProvider.notifier).logout();
    }
  }
}

class _ProfileSection extends StatefulWidget {
  final dynamic user;
  final Map<String, dynamic>? profile;
  final bool isLoading;
  final VoidCallback onReload;
  final Future<bool> Function(String, String) onSave;
  
  const _ProfileSection({
    required this.user, required this.profile, required this.isLoading, required this.onReload, required this.onSave
  });

  @override
  State<_ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends State<_ProfileSection> {
  bool _editing = false;
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user?['full_name'] as String? ?? '');
    _phoneCtrl = TextEditingController(text: widget.profile?['phone'] ?? '');
  }

  @override
  void didUpdateWidget(_ProfileSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user != oldWidget.user && !_editing) {
      _nameCtrl.text = widget.user?['full_name'] as String? ?? '';
    }
    if (widget.profile != oldWidget.profile && !_editing) {
      _phoneCtrl.text = widget.profile?['phone'] ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Account Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 20),
          if (widget.isLoading) const Center(child: CircularProgressIndicator())
          else Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Avatar
            CircleAvatar(
              radius: 36,
              backgroundColor: AppTheme.primaryGold.withOpacity(0.12),
              child: Text(
                ((widget.user?['full_name'] as String? ?? 'U')).substring(0, 1).toUpperCase(),
                style: const TextStyle(color: AppTheme.primaryGold, fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            if (_editing) ...[
              AppTextField(label: 'Display Name', controller: _nameCtrl),
              const SizedBox(height: 12),
              AppTextField(label: 'Phone', controller: _phoneCtrl),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: AppButton(text: 'Save', isLoading: _isSaving, onPressed: () async {
                  setState(() => _isSaving = true);
                  final success = await widget.onSave(_nameCtrl.text.trim(), _phoneCtrl.text.trim());
                  if (mounted) {
                    setState(() { _isSaving = false; if (success) _editing = false; });
                    if (!success) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update profile'), backgroundColor: Colors.red));
                    } else {
                      widget.onReload(); // reload profile to reflect changes (though Riverpod state might update, we fetch /me again)
                    }
                  }
                })),
                const SizedBox(width: 12),
                Expanded(child: AppButton(text: 'Cancel', isSecondary: true, onPressed: () => setState(() => _editing = false))),
              ]),
            ] else ...[
              _InfoRow('Name', widget.user?['full_name'] as String? ?? ''),
              const SizedBox(height: 12),
              _InfoRow('Email', widget.user?['email'] as String? ?? ''),
              const SizedBox(height: 12),
              _InfoRow('Role', (widget.user?['role'] as String? ?? '').toUpperCase()),
              const SizedBox(height: 16),
              AppButton(text: 'Edit Profile', isSecondary: true, icon: Icons.edit, onPressed: () => setState(() => _editing = true)),
            ],
          ]),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Row(children: [
    SizedBox(width: 80, child: Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 13))),
    Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
  ]);
}

class _DangerSection extends StatelessWidget {
  final VoidCallback onLogout;
  final VoidCallback onDeleteAccount;
  const _DangerSection({required this.onLogout, required this.onDeleteAccount});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Account Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 20),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.logout, color: Colors.red, size: 20)),
            title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Sign out of your account on this device'),
            trailing: OutlinedButton(
              onPressed: onLogout,
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), foregroundColor: Colors.red),
              child: const Text('Sign Out'),
            ),
          ),
          const Divider(height: 32),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.withOpacity(0.2))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.warning, color: Colors.red, size: 16),
                SizedBox(width: 8),
                Text('Danger Zone', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
              ]),
              const SizedBox(height: 8),
              Text('Deleting your account is permanent and cannot be undone. All your data will be permanently removed.', style: TextStyle(color: Colors.red.withOpacity(0.7), fontSize: 12, height: 1.4)),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onDeleteAccount,
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), foregroundColor: Colors.red, minimumSize: const Size(double.infinity, 40)),
                child: const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
