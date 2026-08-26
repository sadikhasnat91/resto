import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/network/dio_client.dart';

final selectedPeriodProvider = StateProvider<String>((ref) => 'daily');

final incomeReportsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, period) async {
  final dio = ref.watch(dioClientProvider).dio;
  final res = await dio.get('/api/reports/income', queryParameters: {'period': period});
  return res.data as Map<String, dynamic>;
});

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(selectedPeriodProvider);
    final reportsAsync = ref.watch(incomeReportsProvider(period));
    final currency = NumberFormat.simpleCurrency(name: 'USD');

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row with Timeframe Selector
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 650;
                return isWide
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Income Analytics & Reports', style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 4),
                              Text('Track daily, weekly, monthly, and yearly revenue history', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                            ],
                          ),
                          _PeriodSelector(period: period, onSelected: (p) => ref.read(selectedPeriodProvider.notifier).state = p),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Income Analytics & Reports', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 12),
                          _PeriodSelector(period: period, onSelected: (p) => ref.read(selectedPeriodProvider.notifier).state = p),
                        ],
                      );
              },
            ),
            const SizedBox(height: 28),

            reportsAsync.when(
              loading: () => Column(
                children: [
                  GridView.count(
                    crossAxisCount: 4, crossAxisSpacing: 16, mainAxisSpacing: 16, shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.8,
                    children: List.generate(4, (_) => const AppSkeleton(width: double.infinity, height: 100)),
                  ),
                  const SizedBox(height: 24),
                  const AppSkeleton(width: double.infinity, height: 260),
                ],
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('Error loading reports: $e', style: const TextStyle(color: Colors.red)),
                ),
              ),
              data: (data) {
                final totalIncome = (data['total_income'] as num?)?.toDouble() ?? 0.0;
                final totalOrders = data['total_orders'] as int? ?? 0;
                final completedOrders = data['completed_orders'] as int? ?? 0;
                final totalExpenses = (data['total_expenses'] as num?)?.toDouble() ?? 0.0;
                final netProfit = (data['net_profit'] as num?)?.toDouble() ?? 0.0;
                final avgOrderValue = (data['avg_order_value'] as num?)?.toDouble() ?? 0.0;

                final incomeChart = (data['income_chart'] as List?)?.cast<Map<String, dynamic>>() ?? [];
                final paymentMethods = (data['payment_methods'] as List?)?.cast<Map<String, dynamic>>() ?? [];
                final topItems = (data['top_items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
                final byCategory = (data['revenue_by_category'] as List?)?.cast<Map<String, dynamic>>() ?? [];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // KPI Cards Grid
                    LayoutBuilder(builder: (ctx, c) {
                      final cross = c.maxWidth > 900 ? 4 : (c.maxWidth > 550 ? 2 : 1);
                      return GridView.count(
                        crossAxisCount: cross,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: c.maxWidth > 900 ? 1.7 : 2.2,
                        children: [
                          _MetricTile('Total Income', currency.format(totalIncome), const Color(0xFF10B981), Icons.payments_outlined, subtitle: '$completedOrders completed orders'),
                          _MetricTile('Avg Order Value', currency.format(avgOrderValue), const Color(0xFF3B82F6), Icons.shopping_bag_outlined, subtitle: 'From $totalOrders total orders'),
                          _MetricTile('Total Expenses', currency.format(totalExpenses), const Color(0xFFEF4444), Icons.receipt_long_outlined, subtitle: 'Recorded operational costs'),
                          _MetricTile('Net Profit', currency.format(netProfit), AppTheme.primaryGold, Icons.account_balance_wallet_outlined, subtitle: 'Income minus expenses'),
                        ],
                      );
                    }),
                    const SizedBox(height: 24),

                    // Income Chart Card
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${_periodTitle(period)} Income Trend', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: AppTheme.primaryGold.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                                child: Text('Total: ${currency.format(totalIncome)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 260,
                            child: incomeChart.isEmpty
                                ? const Center(child: Text('No income data for this timeframe.'))
                                : LineChart(
                                    LineChartData(
                                      gridData: FlGridData(
                                        show: true,
                                        drawVerticalLine: false,
                                        getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.withOpacity(0.15), strokeWidth: 1),
                                      ),
                                      titlesData: FlTitlesData(
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 30,
                                            getTitlesWidget: (v, _) {
                                              final idx = v.toInt();
                                              if (idx >= 0 && idx < incomeChart.length) {
                                                return Padding(
                                                  padding: const EdgeInsets.only(top: 8.0),
                                                  child: Text(incomeChart[idx]['label'] ?? '', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                                );
                                              }
                                              return const SizedBox();
                                            },
                                          ),
                                        ),
                                        leftTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 50,
                                            getTitlesWidget: (v, _) => Text('\$${v.toInt()}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                          ),
                                        ),
                                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      ),
                                      borderData: FlBorderData(show: false),
                                      lineBarsData: [
                                        LineChartBarData(
                                          spots: incomeChart.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['income'] as num).toDouble())).toList(),
                                          isCurved: true,
                                          color: AppTheme.primaryGold,
                                          barWidth: 3.5,
                                          isStrokeCapRound: true,
                                          belowBarData: BarAreaData(
                                            show: true,
                                            color: AppTheme.primaryGold.withOpacity(0.12),
                                          ),
                                          dotData: FlDotData(
                                            show: incomeChart.length <= 12,
                                            getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                                              radius: 4, color: AppTheme.primaryGold, strokeWidth: 2, strokeColor: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Payment Method Breakdown + Top Items Row
                    LayoutBuilder(builder: (ctx, c) {
                      final isWide = c.maxWidth > 850;
                      return isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _PaymentMethodsCard(paymentMethods: paymentMethods, currency: currency)),
                                const SizedBox(width: 24),
                                Expanded(child: _TopItemsReport(items: topItems, currency: currency)),
                              ],
                            )
                          : Column(
                              children: [
                                _PaymentMethodsCard(paymentMethods: paymentMethods, currency: currency),
                                const SizedBox(height: 24),
                                _TopItemsReport(items: topItems, currency: currency),
                              ],
                            );
                    }),
                    const SizedBox(height: 24),

                    // Category Pie Chart
                    _CategoryPieChart(categories: byCategory),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _periodTitle(String period) {
    switch (period) {
      case 'daily': return 'Today\'s';
      case 'weekly': return 'This Week\'s';
      case 'monthly': return 'This Month\'s';
      case 'yearly': return 'This Year\'s';
      default: return 'Custom';
    }
  }
}

class _PeriodSelector extends StatelessWidget {
  final String period;
  final ValueChanged<String> onSelected;
  const _PeriodSelector({required this.period, required this.onSelected});

  static const _periods = [
    {'id': 'daily', 'label': 'Daily'},
    {'id': 'weekly', 'label': 'Weekly'},
    {'id': 'monthly', 'label': 'Monthly'},
    {'id': 'yearly', 'label': 'Yearly'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _periods.map((p) {
          final isSel = period == p['id'];
          return GestureDetector(
            onTap: () => onSelected(p['id']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSel ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: isSel ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))] : [],
              ),
              child: Text(
                p['label']!,
                style: TextStyle(
                  fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                  color: isSel ? AppTheme.primaryGold : Colors.grey[700],
                  fontSize: 13,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final String subtitle;
  const _MetricTile(this.label, this.value, this.color, this.icon, {required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: color.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.bold)),
              Icon(icon, color: color, size: 20),
            ],
          ),
          Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
          Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
        ],
      ),
    );
  }
}

class _PaymentMethodsCard extends StatelessWidget {
  final List<Map<String, dynamic>> paymentMethods;
  final NumberFormat currency;
  const _PaymentMethodsCard({required this.paymentMethods, required this.currency});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Payment Method Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 18),
          if (paymentMethods.isEmpty)
            const AppEmptyState(title: 'No Payments', description: 'No payment data collected for this period', icon: Icons.credit_card)
          else
            ...paymentMethods.map((pm) {
              final method = (pm['method'] as String? ?? 'cash').toUpperCase();
              final amount = (pm['amount'] as num?)?.toDouble() ?? 0.0;
              final pct = (pm['percentage'] as num?)?.toDouble() ?? 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(method, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text('${currency.format(amount)}  (${pct.toStringAsFixed(1)}%)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: pct > 0 ? pct / 100 : 0,
                      backgroundColor: Colors.grey[100],
                      valueColor: AlwaysStoppedAnimation(_methodColor(method)),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Color _methodColor(String method) {
    switch (method.toLowerCase()) {
      case 'cash': return const Color(0xFF10B981);
      case 'card': return const Color(0xFF3B82F6);
      case 'mobile': return const Color(0xFF8B5CF6);
      default: return AppTheme.primaryGold;
    }
  }
}

class _TopItemsReport extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final NumberFormat currency;
  const _TopItemsReport({required this.items, required this.currency});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Top Sellers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 18),
          if (items.isEmpty)
            const AppEmptyState(title: 'No Data', description: 'Make some sales first', icon: Icons.restaurant_menu)
          else
            ...items.asMap().entries.map((e) {
              final item = e.value;
              final maxQty = items.fold<int>(0, (m, i) => (i['quantity'] as int) > m ? (i['quantity'] as int) : m);
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14))),
                        Text('${item['quantity']}x  ${currency.format(item['revenue'] ?? 0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: maxQty > 0 ? (item['quantity'] as int) / maxQty : 0,
                      backgroundColor: Colors.grey[100],
                      valueColor: const AlwaysStoppedAnimation(AppTheme.primaryGold),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _CategoryPieChart extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  const _CategoryPieChart({required this.categories});

  static const _colors = [
    Color(0xFFEFB43C), Color(0xFF3B82F6), Color(0xFF10B981),
    Color(0xFFEF4444), Color(0xFF8B5CF6), Color(0xFF6B7280),
  ];

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Revenue by Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          if (categories.isEmpty)
            const AppEmptyState(title: 'No Data', description: 'Category revenue data will appear here.', icon: Icons.pie_chart)
          else
            SizedBox(
              height: 220,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 50,
                        sections: categories.asMap().entries.map((e) {
                          final color = _colors[e.key % _colors.length];
                          final pct = (e.value['percentage'] as num?)?.toDouble() ?? 0.0;
                          return PieChartSectionData(
                            color: color,
                            value: pct > 0 ? pct : 1,
                            title: '${pct.toStringAsFixed(0)}%',
                            radius: 55,
                            titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: categories.asMap().entries.map((e) {
                      final color = _colors[e.key % _colors.length];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Text('${e.value['name'] ?? ''} (${e.value['percentage']}%)', style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
