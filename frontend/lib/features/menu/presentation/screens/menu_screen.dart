import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/network/dio_client.dart';

final menuCategoriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioClientProvider).dio;
  final res = await dio.get('/api/menu/categories');
  return (res.data as List).cast<Map<String, dynamic>>();
});

final menuItemsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioClientProvider).dio;
  final res = await dio.get('/api/menu/items');
  return (res.data as List).cast<Map<String, dynamic>>();
});

class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});
  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Menu Management', style: Theme.of(context).textTheme.titleLarge),
              AppButton(
                text: 'Add Menu Item',
                icon: Icons.add,
                onPressed: () => _showAddItemDialog(context),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.primaryGold,
            labelColor: AppTheme.primaryGold,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            tabs: const [Tab(text: 'Menu Items'), Tab(text: 'Categories')],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _MenuItemsTab(onEdit: _showEditItemDialog, onDelete: _deleteItem),
                _CategoriesTab(onAdd: _showAddCategoryDialog),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddItemDialog(BuildContext context) {
    _showItemDialog(context, null);
  }

  void _showEditItemDialog(BuildContext context, Map<String, dynamic> item) {
    _showItemDialog(context, item);
  }

  void _showItemDialog(BuildContext context, Map<String, dynamic>? existing) {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final priceCtrl = TextEditingController(text: existing?['price']?.toString() ?? '');
    final descCtrl = TextEditingController(text: existing?['description'] ?? '');
    String? catId = existing?['category_id'];
    bool isAvailable = existing?['is_available'] ?? true;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(existing == null ? 'Add Menu Item' : 'Edit Menu Item', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                AppTextField(label: 'Name *', hintText: 'Signature Burger', controller: nameCtrl),
                const SizedBox(height: 16),
                AppTextField(label: 'Price *', hintText: '12.99', controller: priceCtrl, keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                AppTextField(label: 'Description', hintText: 'Delicious...', controller: descCtrl, maxLines: 2),
                const SizedBox(height: 16),
                Consumer(builder: (ctx, ref, _) {
                  final catsAsync = ref.watch(menuCategoriesProvider);
                  return catsAsync.when(
                    loading: () => const CircularProgressIndicator(),
                    error: (_, __) => const Text('Failed to load categories'),
                    data: (cats) => DropdownButtonFormField<String>(
                      value: catId,
                      decoration: InputDecoration(labelText: 'Category *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(6))),
                      items: cats.map((c) => DropdownMenuItem<String>(value: c['id'] as String, child: Text(c['name'] as String))).toList(),
                      onChanged: (v) => setS(() => catId = v),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Available for ordering'),
                  value: isAvailable,
                  activeColor: AppTheme.primaryGold,
                  onChanged: (v) => setS(() => isAvailable = v),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGold, foregroundColor: Colors.black),
              onPressed: () async {
                if (nameCtrl.text.isEmpty || priceCtrl.text.isEmpty || catId == null) return;
                try {
                  final dio = ref.read(dioClientProvider).dio;
                  final data = {
                    'name': nameCtrl.text.trim(),
                    'price': double.tryParse(priceCtrl.text) ?? 0.0,
                    'description': descCtrl.text.trim(),
                    'category_id': catId,
                    'is_available': isAvailable,
                    'variants': [], 'addons': [],
                  };
                  if (existing == null) {
                    await dio.post('/api/menu/items', data: data);
                  } else {
                    await dio.put('/api/menu/items/${existing['id']}', data: data);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  ref.refresh(menuItemsProvider);
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Save failed')));
                }
              },
              child: Text(existing == null ? 'Add Item' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteItem(BuildContext context, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Menu Item?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ref.read(dioClientProvider).dio.delete('/api/menu/items/$id');
        ref.refresh(menuItemsProvider);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delete failed')));
      }
    }
  }

  void _showAddCategoryDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Category'),
        content: AppTextField(label: 'Category Name', hintText: 'Starters', controller: nameCtrl),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGold, foregroundColor: Colors.black),
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              try {
                await ref.read(dioClientProvider).dio.post('/api/menu/categories', data: {'name': nameCtrl.text.trim(), 'display_order': 0});
                if (context.mounted) Navigator.pop(context);
                ref.refresh(menuCategoriesProvider);
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Save failed')));
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _MenuItemsTab extends ConsumerWidget {
  final void Function(BuildContext, Map<String, dynamic>) onEdit;
  final Future<void> Function(BuildContext, String) onDelete;
  const _MenuItemsTab({required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(menuItemsProvider);
    return itemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (items) {
        if (items.isEmpty) return const AppEmptyState(title: 'No menu items yet', description: 'Add your first menu item to get started.', icon: Icons.restaurant_menu);
        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final item = items[i];
            final isAvail = item['is_available'] as bool? ?? true;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryGold.withOpacity(0.12),
                  child: const Icon(Icons.fastfood, color: AppTheme.primaryGold, size: 20),
                ),
                title: Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('\$${item['price']}  ·  ${isAvail ? 'Available' : 'Unavailable'}',
                    style: TextStyle(color: isAvail ? Colors.grey[500] : Colors.red[400], fontSize: 13)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (!isAvail) const Icon(Icons.block, color: Colors.orange, size: 16),
                  IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => onEdit(ctx, item)),
                  IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red), onPressed: () => onDelete(ctx, item['id'])),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}

class _CategoriesTab extends ConsumerWidget {
  final void Function(BuildContext) onAdd;
  const _CategoriesTab({required this.onAdd});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catsAsync = ref.watch(menuCategoriesProvider);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            AppButton(text: 'Add Category', icon: Icons.add, onPressed: () => onAdd(context)),
          ]),
          const SizedBox(height: 16),
          Expanded(child: catsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (cats) => cats.isEmpty
                ? const AppEmptyState(title: 'No categories', description: 'Add a category to organize your menu.', icon: Icons.category)
                : ListView.builder(
                    itemCount: cats.length,
                    itemBuilder: (ctx, i) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: AppTheme.primaryGold.withOpacity(0.12), child: const Icon(Icons.category, color: AppTheme.primaryGold, size: 18)),
                        title: Text(cats[i]['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () async {
                            try {
                              await ref.read(dioClientProvider).dio.delete('/api/menu/categories/${cats[i]['id']}');
                              ref.refresh(menuCategoriesProvider);
                            } catch (e) {
                              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Delete failed')));
                            }
                          },
                        ),
                      ),
                    ),
                  ),
          )),
        ],
      ),
    );
  }
}
