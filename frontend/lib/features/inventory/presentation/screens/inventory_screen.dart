import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/network/dio_client.dart';

final inventoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioClientProvider).dio;
  final res = await dio.get('/api/inventory');
  return (res.data as List).cast<Map<String, dynamic>>();
});

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryAsync = ref.watch(inventoryProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Inventory', style: Theme.of(context).textTheme.titleLarge),
              AppButton(text: 'Add Item', icon: Icons.add, onPressed: () => _showAddDialog(context, ref)),
            ]),
            const SizedBox(height: 20),
            Expanded(
              child: inventoryAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (items) {
                  if (items.isEmpty) return const AppEmptyState(title: 'No inventory items', description: 'Start adding ingredients and supplies.', icon: Icons.inventory);
                  final lowStock = items.where((i) => (i['current_stock'] as num) <= (i['minimum_stock'] as num)).toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (lowStock.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.withOpacity(0.3))),
                          child: Row(children: [
                            const Icon(Icons.warning_amber, color: Colors.orange),
                            const SizedBox(width: 10),
                            Text('${lowStock.length} items are below minimum stock level', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Expanded(
                        child: ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (ctx, i) {
                            final item = items[i];
                            final isLow = (item['current_stock'] as num) <= (item['minimum_stock'] as num);
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: CircleAvatar(
                                  backgroundColor: isLow ? Colors.orange.withOpacity(0.12) : AppTheme.primaryGold.withOpacity(0.12),
                                  child: Icon(Icons.inventory, color: isLow ? Colors.orange : AppTheme.primaryGold, size: 20),
                                ),
                                title: Row(children: [
                                  Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  if (isLow) ...[const SizedBox(width: 8), const Icon(Icons.warning, size: 14, color: Colors.orange)],
                                ]),
                                subtitle: Text('${item['current_stock']} ${item['unit']}  ·  Min: ${item['minimum_stock']} ${item['unit']}  ·  \$${item['cost']}/unit',
                                    style: TextStyle(color: isLow ? Colors.orange : Colors.grey[500], fontSize: 12)),
                                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.primaryGold)),
                                    onPressed: () => _showAdjustDialog(context, ref, item),
                                    child: const Text('Adjust', style: TextStyle(color: AppTheme.primaryGold, fontSize: 12)),
                                  ),
                                ]),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
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
    final stockCtrl = TextEditingController(text: '0');
    final minCtrl = TextEditingController(text: '0');
    final costCtrl = TextEditingController(text: '0');
    String unit = 'pcs';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Add Inventory Item', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                AppTextField(label: 'Name *', hintText: 'Beef Patties', controller: nameCtrl),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: AppTextField(label: 'Current Stock', controller: stockCtrl, keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: AppTextField(label: 'Min Stock', controller: minCtrl, keyboardType: TextInputType.number)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: AppTextField(label: 'Cost Per Unit', controller: costCtrl, keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: DropdownButtonFormField<String>(
                    value: unit,
                    decoration: InputDecoration(labelText: 'Unit', border: OutlineInputBorder(borderRadius: BorderRadius.circular(6))),
                    items: ['pcs', 'kg', 'liters', 'grams', 'ml'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                    onChanged: (v) => setS(() => unit = v!),
                  )),
                ]),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGold, foregroundColor: Colors.black),
              onPressed: () async {
                if (nameCtrl.text.isEmpty) return;
                try {
                  await ref.read(dioClientProvider).dio.post('/api/inventory', data: {
                    'name': nameCtrl.text.trim(), 'unit': unit,
                    'current_stock': double.tryParse(stockCtrl.text) ?? 0,
                    'minimum_stock': double.tryParse(minCtrl.text) ?? 0,
                    'cost': double.tryParse(costCtrl.text) ?? 0,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  ref.refresh(inventoryProvider);
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Failed to add item')));
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAdjustDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> item) {
    final qtyCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    String type = 'in';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('Adjust: ${item['name']}'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Current stock: ${item['current_stock']} ${item['unit']}', style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: InputDecoration(labelText: 'Type', border: OutlineInputBorder(borderRadius: BorderRadius.circular(6))),
                  items: ['in', 'out', 'adjustment', 'purchase'].map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase()))).toList(),
                  onChanged: (v) => setS(() => type = v!),
                ),
                const SizedBox(height: 12),
                AppTextField(label: 'Quantity', controller: qtyCtrl, keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                AppTextField(label: 'Reason', controller: reasonCtrl, hintText: 'Kitchen usage, spoilage...'),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGold, foregroundColor: Colors.black),
              onPressed: () async {
                if (qtyCtrl.text.isEmpty) return;
                try {
                  await ref.read(dioClientProvider).dio.post('/api/inventory/adjustment', data: {
                    'inventory_item_id': item['id'],
                    'type': type,
                    'quantity': double.tryParse(qtyCtrl.text) ?? 0,
                    'reason': reasonCtrl.text.trim(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  ref.refresh(inventoryProvider);
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Adjustment failed')));
                }
              },
              child: const Text('Adjust Stock'),
            ),
          ],
        ),
      ),
    );
  }
}
