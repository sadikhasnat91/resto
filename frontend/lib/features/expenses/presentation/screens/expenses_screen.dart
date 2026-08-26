import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/network/dio_client.dart';

final expensesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioClientProvider).dio;
  final res = await dio.get('/api/expenses');
  return (res.data as List).cast<Map<String, dynamic>>();
});

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expAsync = ref.watch(expensesProvider);
    final currency = NumberFormat.simpleCurrency(name: 'USD');

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Expenses', style: Theme.of(context).textTheme.titleLarge),
              AppButton(text: 'Log Expense', icon: Icons.add, onPressed: () => _showLogDialog(context, ref)),
            ]),
            const SizedBox(height: 20),
            Expanded(
              child: expAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (expenses) {
                  if (expenses.isEmpty) return const AppEmptyState(title: 'No expenses logged', description: 'Log your first expense to track spending.', icon: Icons.receipt);
                  final totalThisMonth = expenses.fold<double>(0, (s, e) => s + (e['amount'] as num).toDouble());
                  return Column(
                    children: [
                      // Summary card
                      AppCard(
                        padding: const EdgeInsets.all(20),
                        child: Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Total Expenses', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                            Text(currency.format(totalThisMonth), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
                          ])),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFFEF4444).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.money_off, color: Color(0xFFEF4444), size: 28),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: ListView.builder(
                          itemCount: expenses.length,
                          itemBuilder: (ctx, i) {
                            final exp = expenses[i];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFFEF4444).withOpacity(0.1),
                                  child: const Icon(Icons.receipt_long, color: Color(0xFFEF4444), size: 20),
                                ),
                                title: Text(exp['description'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('${exp['category'] ?? ''}  ·  ${exp['payment_method'] ?? ''}  ·  ${exp['date'] ?? ''}',
                                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                trailing: Text(currency.format(exp['amount'] ?? 0),
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEF4444), fontSize: 16)),
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

  void _showLogDialog(BuildContext context, WidgetRef ref) {
    final descCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String category = 'food';
    String paymentMethod = 'cash';
    DateTime selectedDate = DateTime.now();

    final categories = ['food', 'utilities', 'salaries', 'maintenance', 'equipment', 'marketing', 'other'];

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Log Expense', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                AppTextField(label: 'Description *', hintText: 'Monthly electricity bill', controller: descCtrl),
                const SizedBox(height: 12),
                AppTextField(label: 'Amount *', hintText: '250.00', controller: amtCtrl, keyboardType: TextInputType.number, prefixIcon: Icons.attach_money),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: InputDecoration(labelText: 'Category', border: OutlineInputBorder(borderRadius: BorderRadius.circular(6))),
                  items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c.toUpperCase()))).toList(),
                  onChanged: (v) => setS(() => category = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: paymentMethod,
                  decoration: InputDecoration(labelText: 'Payment Method', border: OutlineInputBorder(borderRadius: BorderRadius.circular(6))),
                  items: ['cash', 'card', 'bank_transfer', 'mobile'].map((m) => DropdownMenuItem(value: m, child: Text(m.replaceAll('_', ' ').toUpperCase()))).toList(),
                  onChanged: (v) => setS(() => paymentMethod = v!),
                ),
                const SizedBox(height: 12),
                AppTextField(label: 'Notes', hintText: 'Optional notes...', controller: notesCtrl),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGold, foregroundColor: Colors.black),
              onPressed: () async {
                if (descCtrl.text.isEmpty || amtCtrl.text.isEmpty) return;
                try {
                  await ref.read(dioClientProvider).dio.post('/api/expenses', data: {
                    'description': descCtrl.text.trim(),
                    'amount': double.tryParse(amtCtrl.text) ?? 0,
                    'category': category, 'payment_method': paymentMethod,
                    'date': DateFormat('yyyy-MM-dd').format(selectedDate),
                    'notes': notesCtrl.text.trim(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  ref.refresh(expensesProvider);
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Failed to log expense')));
                }
              },
              child: const Text('Log Expense'),
            ),
          ],
        ),
      ),
    );
  }
}
