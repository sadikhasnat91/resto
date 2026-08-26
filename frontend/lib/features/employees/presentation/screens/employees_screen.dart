import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/network/dio_client.dart';

final employeesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioClientProvider).dio;
  final res = await dio.get('/api/admin/staff');
  return (res.data as List).cast<Map<String, dynamic>>();
});

class EmployeesScreen extends ConsumerWidget {
  const EmployeesScreen({super.key});

  static const _roles = ['Manager', 'Cashier', 'Waiter', 'Chef', 'Kitchen Staff'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesAsync = ref.watch(employeesProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Staff & Employees', style: Theme.of(context).textTheme.titleLarge),
              AppButton(text: 'Add Employee', icon: Icons.person_add, onPressed: () => _showAddDialog(context, ref)),
            ]),
            const SizedBox(height: 20),
            Expanded(
              child: employeesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (staff) {
                  if (staff.isEmpty) return const AppEmptyState(title: 'No staff members', description: 'Add staff members to manage your team.', icon: Icons.people);
                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 300, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.2,
                    ),
                    itemCount: staff.length,
                    itemBuilder: (ctx, i) {
                      final s = staff[i];
                      return _EmployeeCard(staff: s, onDelete: () async {
                        try {
                          await ref.read(dioClientProvider).dio.delete('/api/admin/staff/${s['id']}');
                          ref.invalidate(employeesProvider);
                        } catch (e) {
                          if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Delete failed')));
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String role = 'Waiter';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Add Staff Member', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                AppTextField(label: 'Full Name *', hintText: 'John Doe', controller: nameCtrl, prefixIcon: Icons.person_outline),
                const SizedBox(height: 12),
                AppTextField(label: 'Email *', hintText: 'john@restaurant.com', controller: emailCtrl, prefixIcon: Icons.email_outlined),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: InputDecoration(labelText: 'Role', border: OutlineInputBorder(borderRadius: BorderRadius.circular(6))),
                  items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (v) => setS(() => role = v!),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                  ),
                  child: Row(children: [
                    Icon(Icons.info_outline, size: 14, color: Colors.blue[400]),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Staff will receive a temporary password: StaffPassword123!', style: TextStyle(fontSize: 12, color: Colors.blue[400]))),
                  ]),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGold, foregroundColor: Colors.black),
              onPressed: () async {
                if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty) return;
                try {
                  await ref.read(dioClientProvider).dio.post('/api/admin/staff', data: {
                    'full_name': nameCtrl.text.trim(),
                    'email': emailCtrl.text.trim(),
                    'role_names': [role],
                    'phone': null,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  ref.invalidate(employeesProvider);
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Failed to add staff: $e')));
                }
              },
              child: const Text('Add Staff'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  final Map<String, dynamic> staff;
  final VoidCallback onDelete;
  const _EmployeeCard({required this.staff, required this.onDelete});

  Color _roleColor(String name) {
    final r = name.toLowerCase();
    if (r.contains('manager')) return const Color(0xFF8B5CF6);
    if (r.contains('chef') || r.contains('kitchen')) return const Color(0xFFEF4444);
    if (r.contains('cashier')) return const Color(0xFF3B82F6);
    return const Color(0xFF10B981);
  }

  @override
  Widget build(BuildContext context) {
    final fullName = staff['full_name'] as String? ?? 'Staff';
    final email = staff['email'] as String? ?? '';
    final color = _roleColor(fullName);
    final isActive = (staff['status'] as String? ?? 'active') == 'active';

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              radius: 24,
              child: Text(
                fullName.substring(0, 1).toUpperCase(),
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            PopupMenuButton(
              icon: const Icon(Icons.more_vert, size: 18),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 16), SizedBox(width: 8), Text('Remove')])),
              ],
              onSelected: (v) { if (v == 'delete') onDelete(); },
            ),
          ]),
          const SizedBox(height: 12),
          Text(fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(email, style: TextStyle(color: Colors.grey[500], fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
              child: Text('EMPLOYEE', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: isActive ? Colors.green.withValues(alpha: 0.12) : Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(isActive ? 'Active' : 'Inactive', style: TextStyle(color: isActive ? Colors.green : Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ]),
        ],
      ),
    );
  }
}
