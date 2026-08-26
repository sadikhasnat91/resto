import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../core/theme/theme.dart';
import '../dashboard_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: dashAsync.when(
        loading: () => const _DashboardSkeleton(),
        error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text('Unable to load dashboard', style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 16),
          AppButton(text: 'Retry', onPressed: () => ref.refresh(dashboardProvider)),
        ])),
        data: (dash) => _DashboardContent(dash: dash),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final Map<String, dynamic> dash;
  const _DashboardContent({required this.dash});

  @override
  Widget build(BuildContext context) {
    final kpi = dash['kpi'] as Map<String, dynamic>? ?? {};
    final salesChart = (dash['sales_chart'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final topItems = (dash['top_items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final recentOrders = (dash['recent_orders'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final lowStock = (dash['low_stock'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final currency = NumberFormat.simpleCurrency(name: 'USD');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Dashboard', style: Theme.of(context).textTheme.titleLarge),
              Text(DateFormat('EEEE, MMMM d yyyy').format(DateTime.now()),
                  style: TextStyle(color: Colors.grey[500], fontSize: 14)),
            ]),
          ]),
          const SizedBox(height: 28),

          // KPI Cards
          LayoutBuilder(builder: (ctx, constraints) {
            final crossCount = constraints.maxWidth > 900 ? 5 : (constraints.maxWidth > 600 ? 3 : 2);
            return GridView.count(
              crossAxisCount: crossCount,
              crossAxisSpacing: 16, mainAxisSpacing: 16,
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.6,
              children: [
                _KpiCard('Today\'s Sales', currency.format(kpi['today_sales'] ?? 0), Icons.attach_money, const Color(0xFF10B981)),
                _KpiCard('Orders Today', '${kpi['orders_count'] ?? 0}', Icons.receipt_long, const Color(0xFF3B82F6)),
                _KpiCard('Avg Order Value', currency.format(kpi['avg_order_value'] ?? 0), Icons.show_chart, AppTheme.primaryGold),
                _KpiCard('Expenses', currency.format(kpi['today_expenses'] ?? 0), Icons.money_off, const Color(0xFFEF4444)),
                _KpiCard('Net Revenue', currency.format(kpi['net_revenue'] ?? 0), Icons.trending_up, const Color(0xFF8B5CF6)),
              ],
            );
          }),
          const SizedBox(height: 28),

          // Charts Row
          LayoutBuilder(builder: (ctx, constraints) {
            final isWide = constraints.maxWidth > 900;
            return isWide
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(flex: 3, child: _SalesChartCard(salesChart: salesChart)),
                    const SizedBox(width: 20),
                    Expanded(flex: 2, child: _TopItemsCard(topItems: topItems, currency: currency)),
                  ])
                : Column(children: [
                    _SalesChartCard(salesChart: salesChart),
                    const SizedBox(height: 20),
                    _TopItemsCard(topItems: topItems, currency: currency),
                  ]);
          }),
          const SizedBox(height: 28),

          // Recent Orders + Low Stock
          LayoutBuilder(builder: (ctx, constraints) {
            final isWide = constraints.maxWidth > 900;
            return isWide
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(flex: 3, child: _RecentOrdersCard(orders: recentOrders, currency: currency)),
                    const SizedBox(width: 20),
                    Expanded(flex: 2, child: _LowStockCard(items: lowStock)),
                  ])
                : Column(children: [
                    _RecentOrdersCard(orders: recentOrders, currency: currency),
                    const SizedBox(height: 20),
                    _LowStockCard(items: lowStock),
                  ]);
          }),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;
  const _KpiCard(this.title, this.value, this.icon, this.accentColor);

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(
              child: Text(
                title, 
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[500]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: accentColor.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
              child: Icon(icon, size: 14, color: accentColor),
            ),
          ]),
          const SizedBox(height: 4),
          Expanded(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value, 
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: accentColor),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SalesChartCard extends StatelessWidget {
  final List<Map<String, dynamic>> salesChart;
  const _SalesChartCard({required this.salesChart});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sales This Week', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: salesChart.isEmpty
                ? const Center(child: Text('No data yet'))
                : BarChart(
                    BarChartData(
                      maxY: salesChart.fold<double>(0, (p, e) => (e['amount'] as num).toDouble() > p ? (e['amount'] as num).toDouble() : p) * 1.3,
                      barGroups: salesChart.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        return BarChartGroupData(x: idx, barRods: [
                          BarChartRodData(
                            toY: (item['amount'] as num).toDouble(),
                            color: AppTheme.primaryGold,
                            width: 28,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ]);
                      }).toList(),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, _) => Text(salesChart[v.toInt()]['date'] ?? '', style: const TextStyle(fontSize: 11)),
                        )),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TopItemsCard extends StatelessWidget {
  final List<Map<String, dynamic>> topItems;
  final NumberFormat currency;
  const _TopItemsCard({required this.topItems, required this.currency});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Top Selling Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          if (topItems.isEmpty)
            const AppEmptyState(title: 'No sales yet', description: 'Start creating orders to see top items.', icon: Icons.restaurant_menu)
          else
            ...topItems.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Expanded(child: Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14))),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${item['quantity']}x', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGold, fontSize: 14)),
                  Text(currency.format(item['revenue'] ?? 0), style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ]),
              ]),
            )),
        ],
      ),
    );
  }
}

class _RecentOrdersCard extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  final NumberFormat currency;
  const _RecentOrdersCard({required this.orders, required this.currency});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recent Orders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          if (orders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No orders yet today')),
            )
          else
            ...orders.map((order) {
              final status = order['status'] as String? ?? 'pending';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(order['order_number'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(order['order_type'] == 'dine_in' ? 'Dine In' : 'Takeaway', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(currency.format(order['total_amount'] ?? 0), style: const TextStyle(fontWeight: FontWeight.bold)),
                    _StatusChip(status: status),
                  ]),
                ]),
              );
            }),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  Color get _bgColor {
    switch (status) {
      case 'completed': return const Color(0xFFE6F4EA);
      case 'preparing': return const Color(0xFFFEF7E0);
      case 'pending': return const Color(0xFFE8F0FE);
      case 'cancelled': return const Color(0xFFFCE8E6);
      default: return Colors.grey[100]!;
    }
  }

  Color get _textColor {
    switch (status) {
      case 'completed': return const Color(0xFF137333);
      case 'preparing': return const Color(0xFFB06000);
      case 'pending': return const Color(0xFF1A73E8);
      case 'cancelled': return const Color(0xFFC5221F);
      default: return Colors.grey[700]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: _bgColor, borderRadius: BorderRadius.circular(4)),
      child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _textColor)),
    );
  }
}

class _LowStockCard extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _LowStockCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.warning_amber, color: Colors.orange, size: 18),
            const SizedBox(width: 8),
            const Text('Low Stock Alerts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: Text('All inventory levels are healthy ✓', style: TextStyle(color: Colors.green))),
            )
          else
            ...items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                const Icon(Icons.circle, size: 8, color: Colors.orange),
                const SizedBox(width: 12),
                Expanded(child: Text(item['name'] ?? '', style: const TextStyle(fontSize: 14))),
                Text('${item['current_stock']}/${item['minimum_stock']} ${item['unit']}',
                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
              ]),
            )),
        ],
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(children: [
        Row(children: [
          AppSkeleton(width: 200, height: 24),
          const Spacer(),
        ]),
        const SizedBox(height: 28),
        Row(children: List.generate(5, (i) => Expanded(child: Padding(
          padding: EdgeInsets.only(right: i < 4 ? 16 : 0),
          child: const AppSkeleton(width: double.infinity, height: 90),
        )))),
        const SizedBox(height: 28),
        Row(children: [
          Expanded(flex: 3, child: AppSkeleton(width: double.infinity, height: 260)),
          const SizedBox(width: 20),
          Expanded(flex: 2, child: AppSkeleton(width: double.infinity, height: 260)),
        ]),
      ]),
    );
  }
}
