import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/network/dio_client.dart';

final tablesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioClientProvider).dio;
  final res = await dio.get('/api/tables');
  return (res.data as List).cast<Map<String, dynamic>>();
});

class TablesScreen extends ConsumerWidget {
  const TablesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tablesAsync = ref.watch(tablesProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Floor Map', style: Theme.of(context).textTheme.titleLarge),
              AppButton(
                text: 'Add Table',
                icon: Icons.add,
                onPressed: () => _showAddTableDialog(context, ref),
              ),
            ]),
            const SizedBox(height: 8),
            Text('Tap a table to manage status', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
            const SizedBox(height: 20),
            // Legend
            Wrap(spacing: 16, runSpacing: 8, children: [
              _Legend('Available', const Color(0xFF10B981)),
              _Legend('Occupied', const Color(0xFFEF4444)),
              _Legend('Reserved', const Color(0xFF3B82F6)),
              _Legend('Cleaning', const Color(0xFFF59E0B)),
              _Legend('Disabled', Colors.grey),
            ]),
            const SizedBox(height: 20),
            Expanded(
              child: tablesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (tables) {
                  // Group by section
                  final sections = <String, List<Map<String, dynamic>>>{};
                  for (final t in tables) {
                    final s = t['section'] as String? ?? 'Main Hall';
                    sections.putIfAbsent(s, () => []).add(t);
                  }
                  return ListView(
                    children: sections.entries.map((entry) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 160, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.0,
                          ),
                          itemCount: entry.value.length,
                          itemBuilder: (ctx, i) => _TableTile(
                            table: entry.value[i],
                            onTap: () => _showTableDetails(ctx, ref, entry.value[i]),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    )).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _tableColor(String status) {
    switch (status) {
      case 'available': return const Color(0xFF10B981);
      case 'occupied': return const Color(0xFFEF4444);
      case 'reserved': return const Color(0xFF3B82F6);
      case 'cleaning': return const Color(0xFFF59E0B);
      default: return Colors.grey;
    }
  }

  void _showTableDetails(BuildContext context, WidgetRef ref, Map<String, dynamic> table) {
    final statuses = ['available', 'occupied', 'reserved', 'cleaning', 'disabled'];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Table ${table['table_number']}', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Capacity: ${table['capacity']} guests'),
          Text('Section: ${table['section']}'),
          Text('Status: ${table['status']}'),
          const SizedBox(height: 16),
          const Text('Change Status:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: statuses.map((s) => ActionChip(
            label: Text(s, style: const TextStyle(fontSize: 12)),
            backgroundColor: s == table['status'] ? AppTheme.primaryGold.withOpacity(0.2) : null,
            onPressed: () async {
              Navigator.pop(context);
              try {
                final dio = ref.read(dioClientProvider).dio;
                await dio.put('/api/tables/${table['id']}/status', data: {'status': s});
                ref.refresh(tablesProvider);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Update failed')));
              }
            },
          )).toList()),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  void _showAddTableDialog(BuildContext context, WidgetRef ref) {
    final numCtrl = TextEditingController();
    int capacity = 4;
    String section = 'Main Hall';
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Add New Table'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                AppTextField(label: 'Table Number', hintText: 'T-11', controller: numCtrl),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Capacity:'),
                  Row(children: [
                    IconButton(icon: const Icon(Icons.remove), onPressed: () { if (capacity > 1) setS(() => capacity--); }),
                    Text('$capacity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.add), onPressed: () { if (capacity < 20) setS(() => capacity++); }),
                  ]),
                ]),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: section,
                  items: ['Main Hall', 'Terrace', 'VIP', 'Bar'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setS(() => section = v!),
                  decoration: InputDecoration(labelText: 'Section', border: OutlineInputBorder(borderRadius: BorderRadius.circular(6))),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGold, foregroundColor: Colors.black),
              onPressed: () async {
                if (numCtrl.text.isEmpty) return;
                try {
                  final dio = ref.read(dioClientProvider).dio;
                  final tables = await dio.get('/api/tables');
                  final branchId = (tables.data as List).isNotEmpty ? (tables.data as List).first['branch_id'] : null;
                  if (branchId == null) return;
                  await dio.post('/api/tables', data: {'branch_id': branchId, 'table_number': numCtrl.text, 'capacity': capacity, 'section': section});
                  if (ctx.mounted) Navigator.pop(ctx);
                  ref.refresh(tablesProvider);
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Failed to add table')));
                }
              },
              child: const Text('Add Table'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableTile extends StatelessWidget {
  final Map<String, dynamic> table;
  final VoidCallback onTap;
  const _TableTile({required this.table, required this.onTap});

  Color get _color {
    switch (table['status']) {
      case 'available': return const Color(0xFF10B981);
      case 'occupied': return const Color(0xFFEF4444);
      case 'reserved': return const Color(0xFF3B82F6);
      case 'cleaning': return const Color(0xFFF59E0B);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _color.withOpacity(0.5), width: 1.5),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.table_restaurant, color: _color, size: 32),
          const SizedBox(height: 8),
          Text(table['table_number'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _color)),
          const SizedBox(height: 4),
          Text('${table['capacity']} seats', style: TextStyle(fontSize: 11, color: _color.withOpacity(0.7))),
        ]),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final String label;
  final Color color;
  const _Legend(this.label, this.color);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 6),
    Text(label, style: const TextStyle(fontSize: 12)),
  ]);
}
