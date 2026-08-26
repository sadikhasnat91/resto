import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/theme/theme.dart';

class KitchenScreen extends ConsumerStatefulWidget {
  const KitchenScreen({super.key});
  @override
  ConsumerState<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends ConsumerState<KitchenScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  WebSocketChannel? _wsChannel;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _connectWs();
  }

  @override
  void dispose() {
    _wsChannel?.sink.close();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    try {
      final dio = ref.read(dioClientProvider).dio;
      final res = await dio.get('/api/orders');
      final all = (res.data as List).cast<Map<String, dynamic>>();
      setState(() {
        _orders = all.where((o) => ['pending', 'preparing', 'ready'].contains(o['status'])).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _connectWs() {
    final token = ref.read(storageServiceProvider).getAccessToken();
    if (token == null) return;
    try {
      _wsChannel = WebSocketChannel.connect(Uri.parse('${AppConstants.wsUrl}?token=$token'));
      _wsChannel!.stream.listen((data) {
        final msg = jsonDecode(data.toString()) as Map<String, dynamic>;
        final event = msg['event'] as String?;
        if (event == 'order_created' || event == 'order_status_changed') {
          _loadOrders();
        }
      });
    } catch (_) {}
  }

  Future<void> _updateStatus(String orderId, String status) async {
    try {
      final dio = ref.read(dioClientProvider).dio;
      await dio.put('/api/orders/$orderId/status', data: {'status': status});
      _loadOrders();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final columns = [
      {'label': 'NEW', 'statuses': ['pending'], 'color': const Color(0xFF3B82F6)},
      {'label': 'PREPARING', 'statuses': ['preparing'], 'color': const Color(0xFFF59E0B)},
      {'label': 'READY', 'statuses': ['ready'], 'color': const Color(0xFF8B5CF6)},
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: Row(children: [
          const Icon(Icons.kitchen, color: AppTheme.primaryGold),
          const SizedBox(width: 12),
          const Text('Kitchen Display System', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _loadOrders),
          const SizedBox(width: 8),
        ],
      ),
      backgroundColor: const Color(0xFF0A0A0B),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold))
          : Row(
              children: columns.map((col) {
                final statuses = col['statuses'] as List;
                final label = col['label'] as String;
                final color = col['color'] as Color;
                final colOrders = _orders.where((o) => statuses.contains(o['status'])).toList();

                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111113),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        // Column Header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          ),
                          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                              child: Text('${colOrders.length}', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                            ),
                          ]),
                        ),
                        // Orders
                        Expanded(
                          child: colOrders.isEmpty
                              ? Center(child: Text('No orders', style: TextStyle(color: Colors.grey[600])))
                              : ListView.builder(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: colOrders.length,
                                  itemBuilder: (ctx, i) => _KdsOrderCard(
                                    order: colOrders[i],
                                    accent: color,
                                    onAction: _updateStatus,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _KdsOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final Color accent;
  final Future<void> Function(String id, String status) onAction;
  const _KdsOrderCard({required this.order, required this.accent, required this.onAction});

  String get _nextStatus {
    switch (order['status']) {
      case 'pending': return 'preparing';
      case 'preparing': return 'ready';
      case 'ready': return 'completed';
      default: return 'completed';
    }
  }

  String get _actionLabel {
    switch (order['status']) {
      case 'pending': return '🍳 Start Cooking';
      case 'preparing': return '✓ Mark Ready';
      case 'ready': return '✓ Mark Completed';
      default: return 'Complete';
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = (order['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final orderNumber = order['order_number'] ?? '';
    final tableId = order['table_id'];
    final notes = order['notes'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(orderNumber, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            if (tableId != null) Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: accent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
              child: Text('Table', style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF2E2E33), height: 1),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(4)),
                child: Text('×${item['quantity']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(
                item['item_name'] as String? ?? 
                (item['notes'] != null && (item['notes'] as String).isNotEmpty ? item['notes'] as String : 'Item #${items.indexOf(item) + 1}'),
                style: const TextStyle(color: Colors.white, fontSize: 14),
              )),
            ]),
          )),
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
              child: Row(children: [
                const Icon(Icons.sticky_note_2, size: 14, color: Colors.orange),
                const SizedBox(width: 6),
                Expanded(child: Text(notes, style: const TextStyle(color: Colors.orange, fontSize: 12))),
              ]),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => onAction(order['id'], _nextStatus),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(_actionLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}
