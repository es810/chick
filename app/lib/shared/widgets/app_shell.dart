import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/l10n/app_localizations.dart';

typedef NavItem = ({IconData icon, String path});

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.child,
    required this.navigationItems,
    required this.basePath,
  });

  final Widget child;
  final List<NavItem> navigationItems;
  final String basePath;

  bool _showsBottomNav(String location) {
    for (final item in navigationItems) {
      if (location == item.path) return true;
      if (item.path.endsWith('/invoices') && location.startsWith('${item.path}/')) {
        return true;
      }
      if (item.path.endsWith('/collection-invoices') && location.startsWith(item.path)) {
        return true;
      }
      if (item.path.endsWith('/treasury') && location.startsWith(item.path)) {
        return true;
      }
      if (item.path.endsWith('/suppliers') && location.startsWith(item.path)) {
        return true;
      }
    }
    return false;
  }

  int _currentIndex(String location) {
    for (var i = 0; i < navigationItems.length; i++) {
      final path = navigationItems[i].path;
      if (location == path) return i;
      if (path.endsWith('/invoices') && location.startsWith('$path/')) return i;
      if (path.endsWith('/collection-invoices') && location.startsWith(path)) return i;
      if (path.endsWith('/treasury') && location.startsWith(path)) return i;
      if (path.endsWith('/suppliers') && location.startsWith(path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final showBottomNav = _showsBottomNav(location);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: showBottomNav
          ? NavigationBar(
              selectedIndex: _currentIndex(location),
              onDestinationSelected: (i) => context.go(navigationItems[i].path),
              destinations: navigationItems
                  .map(
                    (item) => NavigationDestination(
                      icon: Icon(item.icon),
                      label: l10n.navLabelForPath(item.path),
                    ),
                  )
                  .toList(),
            )
          : null,
    );
  }
}
