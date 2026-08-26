import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/constants.dart';
import '../../../auth/presentation/auth_providers.dart';

// ---- Providers ----
final posMenuItemsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioClientProvider).dio;
  final items = await dio.get('/api/menu/items');
  return (items.data as List).cast<Map<String, dynamic>>();
});

final posCategoriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioClientProvider).dio;
  final res = await dio.get('/api/menu/categories');
  return (res.data as List).cast<Map<String, dynamic>>();
});

final posTablesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioClientProvider).dio;
  final res = await dio.get('/api/tables');
  return (res.data as List).cast<Map<String, dynamic>>();
});

class CartItem {
  final Map<String, dynamic> menuItem;
  int quantity;
  Map<String, dynamic>? selectedVariant;
  List<Map<String, dynamic>> addons;
  String? notes;

  CartItem({required this.menuItem, this.quantity = 1, this.selectedVariant, this.addons = const [], this.notes});

  double get unitPrice {
    double base = selectedVariant?['price_override'] != null
        ? (selectedVariant!['price_override'] as num).toDouble()
        : (menuItem['price'] as num).toDouble();
    double addonsTotal = addons.fold(0, (sum, a) => sum + (a['price'] as num).toDouble());
    return base + addonsTotal;
  }

  double get totalPrice => unitPrice * quantity;
}

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  void addItem(Map<String, dynamic> item, {Map<String, dynamic>? variant, List<Map<String, dynamic>> addons = const []}) {
    final existing = state.where((c) => c.menuItem['id'] == item['id'] &&
        c.selectedVariant?['id'] == variant?['id']).firstOrNull;
    if (existing != null) {
      state = [for (final c in state) if (c == existing) CartItem(menuItem: c.menuItem, quantity: c.quantity + 1, selectedVariant: c.selectedVariant, addons: c.addons) else c];
    } else {
      state = [...state, CartItem(menuItem: item, quantity: 1, selectedVariant: variant, addons: addons)];
    }
  }

  void removeItem(int index) {
    final newState = [...state];
    newState.removeAt(index);
    state = newState;
  }

  void updateQuantity(int index, int qty) {
    if (qty <= 0) { removeItem(index); return; }
    state = [for (int i = 0; i < state.length; i++) i == index ? CartItem(menuItem: state[i].menuItem, quantity: qty, selectedVariant: state[i].selectedVariant, addons: state[i].addons) : state[i]];
  }

  void clear() => state = [];

  double get subtotal => state.fold(0, (sum, item) => sum + item.totalPrice);
  double get tax => state.fold(0, (sum, item) => sum + item.totalPrice * ((item.menuItem['tax_rate'] as num? ?? 0) / 100));
  double get total => subtotal + tax;
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) => CartNotifier());

// ---- POS Screen ----
class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});
  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  String? _selectedCategoryId;
  String _orderType = 'dine_in';
  String? _selectedTableId;
  bool _isCheckingOut = false;

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);
    final itemsAsync = ref.watch(posMenuItemsProvider);
    final catsAsync = ref.watch(posCategoriesProvider);
    final tablesAsync = ref.watch(posTablesProvider);
    final currency = NumberFormat.simpleCurrency(name: 'USD');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: const Text('Point of Sale', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(children: [
              _OrderTypeBtn('Dine In', 'dine_in', _orderType == 'dine_in', () => setState(() => _orderType = 'dine_in')),
              const SizedBox(width: 8),
              _OrderTypeBtn('Takeaway', 'takeaway', _orderType == 'takeaway', () => setState(() {
                _orderType = 'takeaway';
                _selectedTableId = null;
              })),
            ]),
          ),
        ],
      ),
      body: Row(
        children: [
          // LEFT: Categories + Items
          Expanded(
            flex: 6,
            child: Column(
              children: [
                // Category chips
                Container(
                  height: 56,
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: catsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const SizedBox(),
                    data: (cats) => ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      children: [
                        _CategoryChip('All', null, _selectedCategoryId == null, () => setState(() => _selectedCategoryId = null)),
                        ...cats.map((c) => _CategoryChip(c['name'], c['id'], _selectedCategoryId == c['id'], () => setState(() => _selectedCategoryId = c['id']))),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                // Items Grid
                Expanded(
                  child: itemsAsync.when(
                    loading: () => GridView.count(crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12,
                        padding: const EdgeInsets.all(16), childAspectRatio: 0.85,
                        children: List.generate(9, (_) => const AppSkeleton(width: double.infinity, height: 150))),
                    error: (e, _) => const Center(child: Text('Failed to load menu')),
                    data: (items) {
                      final filtered = _selectedCategoryId == null ? items : items.where((i) => i['category_id'] == _selectedCategoryId).toList();
                      if (filtered.isEmpty) return const AppEmptyState(title: 'No items', description: 'No items in this category', icon: Icons.restaurant_menu);
                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 180,
                          crossAxisSpacing: 12, mainAxisSpacing: 12,
                          childAspectRatio: 0.82,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) {
                          final item = filtered[i];
                          final isAvail = item['is_available'] as bool? ?? true;
                          return _MenuItemCard(item: item, isAvailable: isAvail, onAdd: isAvail ? () => cartNotifier.addItem(item) : null);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // RIGHT: Cart
          Container(
            width: 340,
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              border: Border(left: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Current Order', style: Theme.of(context).textTheme.titleMedium),
                    if (cart.isNotEmpty) TextButton(
                      onPressed: () => ref.read(cartProvider.notifier).clear(),
                      child: const Text('Clear', style: TextStyle(color: Colors.red)),
                    ),
                  ]),
                ),
                if (_orderType == 'dine_in') ...[
                  tablesAsync.when(
                    data: (tables) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: DropdownButtonFormField<String>(
                        value: _selectedTableId,
                        decoration: const InputDecoration(
                          labelText: 'Select Table (Optional)',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        dropdownColor: Theme.of(context).cardColor,
                        style: Theme.of(context).textTheme.bodyMedium,
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('No Table'),
                          ),
                          ...tables.map((t) => DropdownMenuItem<String>(
                            value: t['id'] as String,
                            child: Text('${t['table_number']} (${t['section']})'),
                          )),
                        ],
                        onChanged: (val) => setState(() => _selectedTableId = val),
                      ),
                    ),
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                    ),
                    error: (_, __) => const SizedBox(),
                  ),
                  const Divider(height: 1),
                ],
                // Cart Items
                Expanded(
                  child: cart.isEmpty
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey[600]),
                            const SizedBox(height: 12),
                            Text('Cart is empty', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[500])),
                            const SizedBox(height: 4),
                            Text('Tap items to add', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          ],
                        )
                      : ListView.builder(
                          itemCount: cart.length,
                          itemBuilder: (ctx, i) {
                            final item = cart[i];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Row(children: [
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(item.menuItem['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                  if (item.selectedVariant != null) Text(item.selectedVariant!['name'] ?? '', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                ])),
                                Row(children: [
                                  IconButton(icon: const Icon(Icons.remove_circle_outline, size: 20), onPressed: () => ref.read(cartProvider.notifier).updateQuantity(i, item.quantity - 1)),
                                  Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  IconButton(icon: const Icon(Icons.add_circle_outline, size: 20), onPressed: () => ref.read(cartProvider.notifier).updateQuantity(i, item.quantity + 1)),
                                ]),
                                SizedBox(width: 70, child: Text(currency.format(item.totalPrice), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
                              ]),
                            );
                          },
                        ),
                ),
                // Totals
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    _TotalRow('Subtotal', currency.format(cartNotifier.subtotal)),
                    const SizedBox(height: 6),
                    _TotalRow('Tax', currency.format(cartNotifier.tax)),
                    const Divider(height: 20),
                    _TotalRow('Total', currency.format(cartNotifier.total), bold: true),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: AppButton(
                        text: cart.isEmpty ? 'Cart is Empty' : 'Checkout  ${currency.format(cartNotifier.total)}',
                        onPressed: cart.isEmpty ? null : () => _showCheckoutDialog(context, cartNotifier.total, currency),
                        isLoading: _isCheckingOut,
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCheckoutDialog(BuildContext context, double total, NumberFormat currency) {
    String paymentMethod = 'cash';
    final discountController = TextEditingController(text: '0.00');
    double discountAmount = 0.0;
    
    // Net total initialized to the total
    double netTotal = total;
    final cashController = TextEditingController(text: total.toStringAsFixed(2));
    double cashReceived = total;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setS) {
          netTotal = total - discountAmount;
          final change = cashReceived - netTotal;
          final isCashValid = cashReceived >= netTotal;
          final isDiscountValid = discountAmount <= total;

          return AlertDialog(
            title: const Text('Complete Payment', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (discountAmount > 0) ...[
                    Text('Subtotal: ${currency.format(total)}', style: TextStyle(fontSize: 16, color: Colors.grey[400], decoration: TextDecoration.lineThrough)),
                    const SizedBox(height: 4),
                    Text('Discount: -${currency.format(discountAmount)}', style: const TextStyle(fontSize: 16, color: Colors.redAccent)),
                    const SizedBox(height: 8),
                  ],
                  Text('Total to Pay: ${currency.format(netTotal)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryGold)),
                  const SizedBox(height: 24),
                  
                  // Discount Input Field
                  TextFormField(
                    controller: discountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Discount Amount (Optional)',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      final valD = double.tryParse(val) ?? 0.0;
                      if (valD <= total) {
                        setS(() {
                          discountAmount = valD;
                          final newNetTotal = total - valD;
                          // If cash received was equal to the old total, set it to the new net total
                          if (cashReceived == netTotal || cashReceived == total) {
                            cashReceived = newNetTotal;
                            cashController.text = newNetTotal.toStringAsFixed(2);
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  
                  const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, children: [
                    for (final m in ['cash', 'card', 'mobile'])
                      ChoiceChip(
                        label: Text(m.toUpperCase()),
                        selected: paymentMethod == m,
                        onSelected: (_) => setS(() => paymentMethod = m),
                        selectedColor: AppTheme.primaryGold,
                        labelStyle: TextStyle(
                          fontWeight: paymentMethod == m ? FontWeight.bold : null,
                          color: paymentMethod == m ? Colors.black : Colors.white,
                        ),
                      ),
                  ]),
                  if (paymentMethod == 'cash') ...[
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: cashController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Cash Received',
                        prefixText: '\$ ',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        final valD = double.tryParse(val) ?? 0.0;
                        setS(() {
                          cashReceived = valD;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _quickCashBtn('Exact', netTotal, () {
                          cashController.text = netTotal.toStringAsFixed(2);
                          setS(() => cashReceived = netTotal);
                        }),
                        _quickCashBtn('\$5', 5.0, () {
                          if (5.0 >= netTotal) {
                            cashController.text = '5.00';
                            setS(() => cashReceived = 5.0);
                          }
                        }, disabled: 5.0 < netTotal),
                        _quickCashBtn('\$10', 10.0, () {
                          if (10.0 >= netTotal) {
                            cashController.text = '10.00';
                            setS(() => cashReceived = 10.0);
                          }
                        }, disabled: 10.0 < netTotal),
                        _quickCashBtn('\$20', 20.0, () {
                          if (20.0 >= netTotal) {
                            cashController.text = '20.00';
                            setS(() => cashReceived = 20.0);
                          }
                        }, disabled: 20.0 < netTotal),
                        _quickCashBtn('\$50', 50.0, () {
                          if (50.0 >= netTotal) {
                            cashController.text = '50.00';
                            setS(() => cashReceived = 50.0);
                          }
                        }, disabled: 50.0 < netTotal),
                        _quickCashBtn('\$100', 100.0, () {
                          if (100.0 >= netTotal) {
                            cashController.text = '100.00';
                            setS(() => cashReceived = 100.0);
                          }
                        }, disabled: 100.0 < netTotal),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Change to Return:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          isCashValid ? currency.format(change) : 'Insufficient Cash',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isCashValid ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGold, foregroundColor: Colors.black),
                onPressed: (!isDiscountValid || (paymentMethod == 'cash' && !isCashValid))
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        await _placeOrder(
                          paymentMethod,
                          netTotal,
                          discountAmount: discountAmount,
                          cashReceived: paymentMethod == 'cash' ? cashReceived : null,
                          changeReturned: paymentMethod == 'cash' ? change : null,
                        );
                      },
                child: const Text('Confirm Payment', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _quickCashBtn(String label, double value, VoidCallback onPressed, {bool disabled = false}) {
    return Opacity(
      opacity: disabled ? 0.4 : 1.0,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: Size.zero,
          backgroundColor: Colors.grey[800],
          foregroundColor: Colors.white,
        ),
        onPressed: disabled ? null : onPressed,
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Future<void> _placeOrder(
    String paymentMethod,
    double total, {
    double discountAmount = 0.0,
    double? cashReceived,
    double? changeReturned,
  }) async {
    setState(() => _isCheckingOut = true);
    final cartCopy = [...ref.read(cartProvider)];
    final subtotalCopy = ref.read(cartProvider.notifier).subtotal;
    final taxCopy = ref.read(cartProvider.notifier).tax;

    String? selectedTableName;
    if (_orderType == 'dine_in' && _selectedTableId != null) {
      final tablesAsync = ref.read(posTablesProvider);
      tablesAsync.whenData((tables) {
        final t = tables.firstWhere((t) => t['id'] == _selectedTableId, orElse: () => {});
        if (t.isNotEmpty) {
          selectedTableName = '${t['table_number']} (${t['section']})';
        }
      });
    }

    try {
      final dio = ref.read(dioClientProvider).dio;
      final cart = ref.read(cartProvider);
      final cartNotifier = ref.read(cartProvider.notifier);

      // Get branch ID from branches endpoint
      String? branchId;
      try {
        final branchesRes = await dio.get('/api/branches');
        final branches = (branchesRes.data as List).cast<Map<String, dynamic>>();
        if (branches.isNotEmpty) {
          branchId = branches.first['id'] as String?;
        }
      } catch (_) {}

      if (branchId == null) {
        throw Exception('No branch configured. Please complete restaurant onboarding first.');
      }

      // Create order
      final orderRes = await dio.post('/api/orders', data: {
        'branch_id': branchId,
        'table_id': _orderType == 'dine_in' ? _selectedTableId : null,
        'order_type': _orderType,
        'discount_amount': discountAmount,
        'items': cart.map((item) => {
          'menu_item_id': item.menuItem['id'],
          'quantity': item.quantity,
          'selected_variant_id': item.selectedVariant?['id'],
          'addon_ids': item.addons.map((a) => a['id']).toList(),
        }).toList(),
      });

      final orderId = orderRes.data['id'];
      final orderNumber = orderRes.data['order_number'];

      // Process payment
      await dio.post('/api/orders/$orderId/payment', data: {
        'payment_method': paymentMethod,
        'amount': total,
      });

      cartNotifier.clear();
      setState(() {
        _selectedTableId = null;
      });

      if (mounted) {
        _showReceiptDialog(
          context: context,
          orderNumber: orderNumber,
          dateTime: DateTime.now(),
          items: cartCopy,
          subtotal: subtotalCopy,
          tax: taxCopy,
          discountAmount: discountAmount,
          total: total, // Pass the net total
          tableName: selectedTableName,
          paymentMethod: paymentMethod,
          cashReceived: cashReceived,
          changeReturned: changeReturned,
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('Exception:') 
            ? e.toString().replaceFirst('Exception: ', '')
            : 'Failed to process order. Please retry.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingOut = false);
    }
  }

  void _showReceiptDialog({
    required BuildContext context,
    required String orderNumber,
    required DateTime dateTime,
    required List<CartItem> items,
    required double subtotal,
    required double tax,
    required double discountAmount,
    required double total,
    required String? tableName,
    required String paymentMethod,
    required double? cashReceived,
    required double? changeReturned,
  }) {
    final currency = NumberFormat.simpleCurrency(name: 'USD');
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    final authState = ref.read(authProvider);
    final restaurantName = authState.restaurant?['name'] as String? ?? AppConstants.appName;
    final restaurantAddress = authState.restaurant?['address'] as String?;
    final restaurantPhone = authState.restaurant?['phone'] as String?;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Container(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                const SizedBox(height: 12),
                const Text(
                  'Payment Successful',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.grey),
                Center(
                  child: Text(
                    restaurantName.toUpperCase(),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.primaryGold, letterSpacing: 2.0),
                  ),
                ),
                if (restaurantAddress != null && restaurantAddress.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      restaurantAddress,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    ),
                  ),
                ],
                if (restaurantPhone != null && restaurantPhone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      'Phone: $restaurantPhone',
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const Divider(color: Colors.white24),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Order Number: $orderNumber',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    'Date: ${dateFormat.format(dateTime)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                ),
                if (tableName != null) ...[
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      'Table: $tableName',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGold),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text('ITEMS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                const Divider(color: Colors.white24),
                for (final item in items) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item.menuItem['name']}',
                                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                              if (item.selectedVariant != null)
                                Text(
                                  ' - ${item.selectedVariant!['name']}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          'x${item.quantity}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          currency.format(item.totalPrice),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
                const Divider(color: Colors.white24),
                _receiptRow('Subtotal', currency.format(subtotal)),
                _receiptRow('Tax', currency.format(tax)),
                if (discountAmount > 0) ...[
                  _receiptRow('Discount', '-${currency.format(discountAmount)}', highlightColor: Colors.redAccent),
                ],
                const Divider(color: Colors.white24),
                _receiptRow('Total Bill', currency.format(total), bold: true),
                const SizedBox(height: 12),
                const Text('PAYMENT INFO', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                const Divider(color: Colors.white24),
                _receiptRow('Method', paymentMethod.toUpperCase()),
                if (paymentMethod == 'cash') ...[
                  _receiptRow('Cash Received', currency.format(cashReceived ?? total)),
                  _receiptRow('Change Returned', currency.format(changeReturned ?? 0.0), highlightColor: Colors.green),
                ],
                const Divider(color: Colors.grey),
                const SizedBox(height: 12),
                const Text(
                  'Thank you for dining with us!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontStyle: FontStyle.italic, color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryGold,
                    side: const BorderSide(color: AppTheme.primaryGold),
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  onPressed: () => _printReceipt(
                    orderNumber: orderNumber,
                    dateTime: dateTime,
                    items: items,
                    subtotal: subtotal,
                    tax: tax,
                    discountAmount: discountAmount,
                    total: total,
                    tableName: tableName,
                    paymentMethod: paymentMethod,
                    cashReceived: cashReceived,
                    changeReturned: changeReturned,
                  ),
                  icon: const Icon(Icons.print),
                  label: const Text('PRINT RECEIPT', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGold,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('DONE', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _printReceipt({
    required String orderNumber,
    required DateTime dateTime,
    required List<CartItem> items,
    required double subtotal,
    required double tax,
    required double discountAmount,
    required double total,
    required String? tableName,
    required String paymentMethod,
    required double? cashReceived,
    required double? changeReturned,
  }) {
    if (!kIsWeb) return;

    final currency = NumberFormat.simpleCurrency(name: 'USD');
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    final authState = ref.read(authProvider);
    final restaurantName = authState.restaurant?['name'] as String? ?? AppConstants.appName;
    final restaurantAddress = authState.restaurant?['address'] as String?;
    final restaurantPhone = authState.restaurant?['phone'] as String?;

    final itemsHtml = items.map((item) {
      final variantText = item.selectedVariant != null ? ' - ${item.selectedVariant!['name']}' : '';
      return '''
        <tr>
          <td style="padding: 5px 0;">${item.menuItem['name']}$variantText</td>
          <td style="padding: 5px 0; text-align: center;">x${item.quantity}</td>
          <td style="padding: 5px 0; text-align: right;">${currency.format(item.totalPrice)}</td>
        </tr>
      ''';
    }).join('');

    final tableRow = tableName != null 
        ? '<p style="text-align: center; margin: 5px 0;"><b>Table: $tableName</b></p>'
        : '';

    final cashRows = paymentMethod == 'cash' 
        ? '''
          <tr>
            <td style="padding: 3px 0;">Cash Received</td>
            <td></td>
            <td style="text-align: right;">${currency.format(cashReceived ?? total)}</td>
          </tr>
          <tr>
            <td style="padding: 3px 0;"><b>Change Returned</b></td>
            <td></td>
            <td style="text-align: right; color: green;"><b>${currency.format(changeReturned ?? 0.0)}</b></td>
          </tr>
        '''
        : '';

    final htmlContent = '''
      <html>
        <head>
          <title>Receipt - $orderNumber</title>
          <style>
            body {
              font-family: 'Courier New', Courier, monospace;
              padding: 20px;
              color: #000;
              background: #fff;
              font-size: 14px;
            }
            .divider {
              border-top: 1px dashed #000;
              margin: 10px 0;
            }
            table {
              width: 100%;
              border-collapse: collapse;
            }
          </style>
        </head>
        <body>
          <h2 style="text-align: center; margin: 0 0 5px 0;">${restaurantName.toUpperCase()}</h2>
          ${restaurantAddress != null && restaurantAddress.isNotEmpty ? '<p style="text-align: center; margin: 3px 0; font-size: 12px;">$restaurantAddress</p>' : ''}
          ${restaurantPhone != null && restaurantPhone.isNotEmpty ? '<p style="text-align: center; margin: 3px 0; font-size: 12px;">Phone: $restaurantPhone</p>' : ''}
          <div class="divider"></div>
          <p style="text-align: center; margin: 5px 0;"><b>Receipt</b></p>
          <p style="text-align: center; margin: 5px 0;">Order #: $orderNumber</p>
          <p style="text-align: center; margin: 5px 0;">Date: ${dateFormat.format(dateTime)}</p>
          $tableRow
          <div class="divider"></div>
          <table>
            <thead>
              <tr style="border-bottom: 1px solid #000;">
                <th style="text-align: left; padding-bottom: 5px;">Item</th>
                <th style="text-align: center; padding-bottom: 5px;">Qty</th>
                <th style="text-align: right; padding-bottom: 5px;">Price</th>
              </tr>
            </thead>
            <tbody>
              $itemsHtml
            </tbody>
          </table>
          <div class="divider"></div>
          <table>
            <tbody>
              <tr>
                <td style="padding: 3px 0;">Subtotal</td>
                <td></td>
                <td style="text-align: right;">${currency.format(subtotal)}</td>
              </tr>
              <tr>
                <td style="padding: 3px 0;">Tax</td>
                <td></td>
                <td style="text-align: right;">${currency.format(tax)}</td>
              </tr>
              ${discountAmount > 0 
                ? '''
                  <tr>
                    <td style="padding: 3px 0; color: red;">Discount</td>
                    <td></td>
                    <td style="text-align: right; color: red;">-${currency.format(discountAmount)}</td>
                  </tr>
                ''' 
                : ''}
              <tr style="border-top: 1px solid #000;">
                <td style="padding: 5px 0;"><b>Total Bill</b></td>
                <td></td>
                <td style="text-align: right;"><b>${currency.format(total)}</b></td>
              </tr>
            </tbody>
          </table>
          <div class="divider"></div>
          <table>
            <tbody>
              <tr>
                <td style="padding: 3px 0;">Payment Method</td>
                <td></td>
                <td style="text-align: right;">${paymentMethod.toUpperCase()}</td>
              </tr>
              $cashRows
            </tbody>
          </table>
          <div class="divider"></div>
          <p style="text-align: center; font-style: italic; margin-top: 20px;">Thank you for dining with us!</p>
          <script>
            window.onload = function() {
              window.print();
              setTimeout(function() { window.close(); }, 500);
            }
          </script>
        </body>
      </html>
    ''';

    final jsCode = """
      (function(html) {
        var printWindow = window.open('', '_blank', 'width=450,height=600');
        printWindow.document.write(html);
        printWindow.document.close();
      })
    """;

    js.context.callMethod('eval', [jsCode])(htmlContent);
  }

  Widget _receiptRow(String label, String value, {bool bold = false, Color? highlightColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : null, color: bold ? Colors.white : Colors.white70)),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : null,
              color: highlightColor ?? (bold ? AppTheme.primaryGold : Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderTypeBtn extends StatelessWidget {
  final String label, value;
  final bool selected;
  final VoidCallback onTap;
  const _OrderTypeBtn(this.label, this.value, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryGold : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: selected ? AppTheme.primaryGold : Colors.grey[400]!),
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.black : Colors.grey[600], fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final String? id;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip(this.label, this.id, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryGold : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppTheme.primaryGold : Colors.grey[400]!),
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.black : null, fontWeight: selected ? FontWeight.bold : null, fontSize: 13)),
      ),
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isAvailable;
  final VoidCallback? onAdd;
  const _MenuItemCard({required this.item, required this.isAvailable, this.onAdd});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency(name: 'USD');
    return InkWell(
      onTap: onAdd,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                child: item['image_url'] != null
                    ? Image.network(item['image_url'], fit: BoxFit.cover, width: double.infinity,
                        errorBuilder: (_, __, ___) => const _PlaceholderImage())
                    : const _PlaceholderImage(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(currency.format(item['price'] ?? 0), style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 14)),
                  if (!isAvailable) const Icon(Icons.block, size: 16, color: Colors.red),
                ]),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderImage extends StatelessWidget {
  const _PlaceholderImage();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[100],
      child: const Center(child: Icon(Icons.restaurant, color: Colors.grey, size: 32)),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _TotalRow(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: bold ? 16 : 14, fontWeight: bold ? FontWeight.bold : null)),
      Text(value, style: TextStyle(fontSize: bold ? 18 : 14, fontWeight: bold ? FontWeight.bold : null, color: bold ? AppTheme.primaryGold : null)),
    ]);
  }
}
