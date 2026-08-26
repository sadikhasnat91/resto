import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../storage/storage_service.dart';
import '../theme/theme.dart';
import '../../features/auth/presentation/auth_providers.dart';

class NavigationShell extends ConsumerWidget {
  final Widget child;

  const NavigationShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;
    final isTablet = size.width <= 1024 && size.width > 768;
    final isMobile = size.width <= 768;

    final location = GoRouterState.of(context).uri.toString();
    final authState = ref.watch(authProvider);
    final restaurantName = authState.restaurant?['name'] ?? 'RestroFlow';
    final userName = authState.user?['full_name'] ?? 'User';

    // Navigation Items Definition
    final navItems = [
      _NavItem('Dashboard', '/dashboard', Icons.dashboard),
      _NavItem('POS Checkout', '/pos', Icons.point_of_sale, isFullScreen: true),
      _NavItem('KDS Screen', '/kitchen', Icons.kitchen, isFullScreen: true),
      _NavItem('Orders', '/orders', Icons.receipt_long),
      _NavItem('Tables Floor', '/tables', Icons.table_restaurant),
      _NavItem('Menu Items', '/menu', Icons.restaurant_menu),
      _NavItem('Inventory', '/inventory', Icons.inventory),
      _NavItem('Staff RBAC', '/employees', Icons.people),
      _NavItem('Expenses', '/expenses', Icons.money_off),
      _NavItem('Reports', '/reports', Icons.bar_chart),
      _NavItem('Settings', '/settings', Icons.settings),
    ];

    void onNavSelect(String path, bool isFullScreen) {
      if (isFullScreen) {
        context.push(path);
      } else {
        context.go(path);
      }
    }

    if (isMobile) {
      // Mobile Layout: Bottom Nav for primary actions + Hamburger Drawer for rest
      final bottomItems = navItems.where((item) => ['/dashboard', '/orders', '/tables'].contains(item.path)).toList();
      int currentIndex = bottomItems.indexWhere((item) => location.startsWith(item.path));
      if (currentIndex == -1) currentIndex = 0;

      return Scaffold(
        appBar: AppBar(
          title: Text(
            restaurantName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          actions: [
            IconButton(
              icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
              onPressed: () => ref.read(themeModeProvider.notifier).setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark),
            ),
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => context.go('/settings'),
            ),
          ],
        ),
        drawer: Drawer(
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1)),
                accountName: Text(userName, style: TextStyle(color: theme.colorScheme.onBackground, fontWeight: FontWeight.bold)),
                accountEmail: Text(authState.user?['email'] ?? '', style: TextStyle(color: theme.colorScheme.onBackground.withOpacity(0.7))),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: theme.colorScheme.primary,
                  child: Text(userName.substring(0, 1).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: navItems.map((item) {
                    final selected = location.startsWith(item.path);
                    return ListTile(
                      leading: Icon(item.icon, color: selected ? theme.colorScheme.primary : null),
                      title: Text(item.title, style: TextStyle(fontWeight: selected ? FontWeight.bold : null)),
                      selected: selected,
                      onTap: () {
                        Navigator.pop(context); // Close Drawer
                        onNavSelect(item.path, item.isFullScreen);
                      },
                    );
                  }).toList(),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Logout', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(authProvider.notifier).logout();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        body: child,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: currentIndex,
          selectedItemColor: theme.colorScheme.primary,
          unselectedItemColor: theme.hintColor,
          onTap: (index) => onNavSelect(bottomItems[index].path, false),
          items: bottomItems.map((item) {
            return BottomNavigationBarItem(
              icon: Icon(item.icon),
              label: item.title,
            );
          }).toList(),
        ),
      );
    }

    // Desktop/Tablet Sidebar layout
    return Scaffold(
      body: Row(
        children: [
          // Navigation Sidebar / Rail
          Container(
            width: isDesktop ? 260 : 80,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              border: Border(
                right: BorderSide(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                ),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 24),
                // Logo Section
                if (isDesktop) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Row(
                      children: [
                        Icon(Icons.restaurant, color: theme.colorScheme.primary, size: 28),
                        const SizedBox(width: 12),
                        const Text(
                          'RESTROFLOW',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Icon(Icons.restaurant, color: theme.colorScheme.primary, size: 28),
                ],
                const SizedBox(height: 32),
                // Navigation Links
                Expanded(
                  child: ListView.builder(
                    itemCount: navItems.length,
                    itemBuilder: (context, index) {
                      final item = navItems[index];
                      final selected = location.startsWith(item.path);
                      
                      if (isDesktop) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2),
                          child: InkWell(
                            onTap: () => onNavSelect(item.path, item.isFullScreen),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: selected ? theme.colorScheme.primary.withOpacity(0.1) : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    item.icon,
                                    size: 20,
                                    color: selected ? theme.colorScheme.primary : theme.hintColor,
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    item.title,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                      color: selected ? theme.colorScheme.primary : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      } else {
                        // Tablet compact rail item
                        return Tooltip(
                          message: item.title,
                          child: IconButton(
                            icon: Icon(item.icon),
                            color: selected ? theme.colorScheme.primary : theme.hintColor,
                            onPressed: () => onNavSelect(item.path, item.isFullScreen),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        );
                      }
                    },
                  ),
                ),
                // Footer Profile and settings
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      if (isDesktop) ...[
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: theme.colorScheme.primary,
                              child: Text(
                                userName.substring(0, 1).toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 14),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    userName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    restaurantName,
                                    style: TextStyle(color: theme.hintColor, fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.logout, size: 18, color: Colors.redAccent),
                              onPressed: () => ref.read(authProvider.notifier).logout(),
                            ),
                          ],
                        ),
                      ] else ...[
                        IconButton(
                          icon: const Icon(Icons.logout, color: Colors.redAccent),
                          onPressed: () => ref.read(authProvider.notifier).logout(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // Top Bar
                Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkBg : Colors.white,
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      // Branch Selector representation
                      Row(
                        children: [
                          Icon(Icons.store, size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          const Text(
                            'Main Street Branch',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Light/Dark Toggle
                      IconButton(
                        icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                        onPressed: () => ref.read(themeModeProvider.notifier).setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark),
                      ),
                      const SizedBox(width: 16),
                      // Notifications panel action
                      Stack(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications_outlined),
                            onPressed: () => context.go('/settings'),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Actual Screen Body
                Expanded(
                  child: child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final String title;
  final String path;
  final IconData icon;
  final bool isFullScreen;

  _NavItem(this.title, this.path, this.icon, {this.isFullScreen = false});
}
