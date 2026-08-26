import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/network/dio_client.dart';

final ordersFilterProvider = StateProvider<String>((ref) => 'all');
final ordersSearchProvider = StateProvider<String>((ref) => '');

final ordersListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final filter = ref.watch(ordersFilterProvider);
  final search = ref.watch(ordersSearchProvider);
  final dio = ref.watch(dioClientProvider).dio;

  final Map<String, dynamic> query = {};
  if (filter != 'all') query['status'] = filter;
  if (search.isNotEmpty) query['search'] = search;

  final res = await dio.get('/api/orders', queryParameters: query);
  return (res.data as List).cast<Map<String, dynamic>>();
});

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});
  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  static const _statuses = [
    {'id': 'all', 'label': 'All History'},
    {'id': 'pending', 'label': 'Pending'},
    {'id': 'preparing', 'label': 'Preparing'},
    {'id': 'ready', 'label': 'Ready'},
    {'id': 'completed', 'label': 'Completed'},
    {'id': 'cancelled', 'label': 'Cancelled'},
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(ordersFilterProvider);
    final ordersAsync = ref.watch(ordersListProvider);
    final currency = NumberFormat.simpleCurrency(name: 'USD');

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Title & Search Bar
            LayoutBuilder(builder: (ctx, constraints) {
              final isWide = constraints.maxWidth > 650;
              return isWide
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Order Management & History', style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 4),
                            Text('View, search, and manage all active & past orders', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                          ],
                        ),
                        SizedBox(
                          width: 280,
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: (val) => ref.read(ordersSearchProvider.notifier).state = val,
                            decoration: InputDecoration(
                              hintText: 'Search order #...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              suffixIcon: _searchCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        ref.read(ordersSearchProvider.notifier).state = '';
                                      },
                                    )
                                  : null,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Order Management & History', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _searchCtrl,
                          onChanged: (val) => ref.read(ordersSearchProvider.notifier).state = val,
                          decoration: InputDecoration(
                            hintText: 'Search order #...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    );
            }),
            const SizedBox(height: 20),

            // Status Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _statuses.map((s) {
                  final selected = filter == s['id'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(s['label']!),
                      selected: selected,
                      onSelected: (_) => ref.read(ordersFilterProvider.notifier).state = s['id']!,
                      selectedColor: AppTheme.primaryGold,
                      labelStyle: TextStyle(
                        fontWeight: selected ? FontWeight.bold : null,
                        color: selected ? Colors.black : Colors.grey[800],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // Orders List View
            Expanded(
              child: ordersAsync.when(
                loading: () => ListView.builder(
                  itemCount: 6,
                  itemBuilder: (_, __) => const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: AppSkeleton(width: double.infinity, height: 85),
                  ),
                ),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Failed to load orders: $e', style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(ordersListProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (orders) {
                  if (orders.isEmpty) {
                    return const AppEmptyState(
                      title: 'No Orders Saved',
                      description: 'No orders found for the selected filter or search term.',
                      icon: Icons.receipt_long,
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(ordersListProvider),
                    child: ListView.builder(
                      itemCount: orders.length,
                      itemBuilder: (ctx, i) {
                        final order = orders[i];
                        return _OrderCard(
                          order: order,
                          currency: currency,
                          onStatusUpdate: (status) async {
                            try {
                              final dio = ref.read(dioClientProvider).dio;
                              await dio.put('/api/orders/${order['id']}/status', data: {'status': status});
                              ref.invalidate(ordersListProvider);
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Failed to update order status')));
                              }
                            }
                          },
                          onViewDetails: () => _showOrderDetailsDialog(context, ref, order, currency),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOrderDetailsDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> order, NumberFormat currency) {
    showDialog(
      context: context,
      builder: (ctx) {
        final items = (order['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final payments = (order['payments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final status = order['status'] as String? ?? 'pending';
        final createdAtStr = order['created_at'] != null ? DateFormat('MMM dd, yyyy - hh:mm a').format(DateTime.parse(order['created_at'])) : '';

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          titlePadding: const EdgeInsets.all(20),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order['order_number'] ?? 'Order Receipt', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 4),
                  Text(createdAtStr, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
              _StatusBadge(status: status),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  Text('Type: ${order['order_type']?.toString().replaceAll('_', ' ').toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 12),
                  const Text('Order Items:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  if (items.isEmpty)
                    const Text('No line items recorded.', style: TextStyle(color: Colors.grey, fontSize: 13))
                  else
                    Container(
                      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[200]!)),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: items.map((item) {
                          final qty = item['quantity'] ?? 1;
                          final price = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${qty}x Item #${item['menu_item_id']?.toString().substring(0, 5) ?? ''}', style: const TextStyle(fontSize: 13)),
                                Text(currency.format(qty * price), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 16),
                  
                  // Summary lines
                  _ReceiptRow('Subtotal:', currency.format(order['subtotal'] ?? 0)),
                  _ReceiptRow('Tax:', currency.format(order['tax_amount'] ?? 0)),
                  if ((order['discount_amount'] as num? ?? 0) > 0)
                    _ReceiptRow('Discount:', '-${currency.format(order['discount_amount'])}', isDiscount: true),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(currency.format(order['total_amount'] ?? 0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryGold)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Payments history
                  const Text('Payment History:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  if (payments.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(6)),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.orange),
                          SizedBox(width: 6),
                          Text('Unpaid / Pending Checkout', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  else
                    ...payments.map((p) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Method: ${(p['payment_method'] as String? ?? 'cash').toUpperCase()}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(currency.format(p['amount'] ?? 0), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                            ],
                          ),
                        )),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDiscount;
  const _ReceiptRow(this.label, this.value, {this.isDiscount = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDiscount ? Colors.red : Colors.black87)),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final NumberFormat currency;
  final Future<void> Function(String) onStatusUpdate;
  final VoidCallback onViewDetails;

  const _OrderCard({
    required this.order,
    required this.currency,
    required this.onStatusUpdate,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final status = order['status'] as String? ?? 'pending';
    final total = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
    final itemsCount = (order['items'] as List?)?.length ?? 0;
    final createdAtStr = order['created_at'] != null ? DateFormat('MMM dd, hh:mm a').format(DateTime.parse(order['created_at'])) : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: onViewDetails,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(order['order_number'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(width: 12),
                        _StatusBadge(status: status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('$itemsCount items  ·  ${order['order_type']?.toString().replaceAll('_', ' ')}  ·  $createdAtStr', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(currency.format(total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryGold)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.receipt_long_outlined, size: 20),
                        tooltip: 'View Details',
                        onPressed: onViewDetails,
                      ),
                      if (status == 'pending')
                        _QuickBtn('Start Cooking', Colors.orange, () => onStatusUpdate('preparing')),
                      if (status == 'preparing')
                        _QuickBtn('Mark Ready', Colors.purple, () => onStatusUpdate('ready')),
                      if (status == 'ready')
                        _QuickBtn('Complete', Colors.green, () => onStatusUpdate('completed')),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  Color get _statusColor {
    switch (status) {
      case 'completed': return const Color(0xFF10B981);
      case 'preparing': return const Color(0xFFF59E0B);
      case 'pending': return const Color(0xFF3B82F6);
      case 'cancelled': return const Color(0xFFEF4444);
      case 'ready': return const Color(0xFF8B5CF6);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: _statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
      child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _statusColor)),
    );
  }
}

class _QuickBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickBtn(this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
