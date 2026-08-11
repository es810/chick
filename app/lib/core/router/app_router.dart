import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/clients/screens/clients_screen.dart';
import '../../features/suppliers/screens/suppliers_screen.dart';
import '../../features/suppliers/screens/supplier_stock_screen.dart';
import '../../features/account_statement/screens/account_statement_screen.dart';
import '../../features/dashboard/screens/admin_dashboard_screen.dart';
import '../../features/treasury/screens/collection_invoices_screen.dart';
import '../../features/treasury/screens/employee_treasury_statement_screen.dart';
import '../../features/treasury/screens/admin_treasury_screen.dart';
import '../../features/dashboard/screens/client_dashboard_screen.dart';
import '../../features/dashboard/screens/employee_dashboard_screen.dart';
import '../../features/invoices/screens/edit_invoice_screen.dart';
import '../../features/invoices/screens/create_invoice_screen.dart';
import '../../features/invoices/screens/invoice_detail_screen.dart';
import '../../features/invoices/screens/invoices_list_screen.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../features/settings/screens/employee_detail_screen.dart';
import '../../features/settings/screens/employees_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/stock/screens/damaged_stock_screen.dart';
import '../../features/stock/screens/stock_screen.dart';
import '../../models/user_model.dart';
import '../../shared/widgets/app_shell.dart';
import 'router_refresh.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Keys must live with this GoRouter instance. Module-level keys collide on
  // Chrome hot reload when a new GoRouter mounts before the old tree is gone
  // (go_router keys Navigators with GlobalObjectKey(navigatorKey.hashCode)).
  final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  final adminShellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'adminShell');
  final employeeShellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'employeeShell');
  final clientShellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'clientShell');

  final refreshListenable = RouterRefreshNotifier(ref);
  ref.onDispose(refreshListenable.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final location = state.matchedLocation;
      final isLoggingIn = location == '/login';
      final isSplash = location == '/splash';

      if (authState.isLoading) return null;

      if (isSplash) {
        if (authState.isAuthenticated) {
          return switch (authState.user!.role) {
            UserRole.admin => '/admin/dashboard',
            UserRole.employee => '/employee/dashboard',
            UserRole.client => '/client/dashboard',
          };
        }
        return '/login';
      }

      if (!authState.isAuthenticated && !isLoggingIn) return '/login';

      if (authState.isAuthenticated && isLoggingIn) {
        return switch (authState.user!.role) {
          UserRole.admin => '/admin/dashboard',
          UserRole.employee => '/employee/dashboard',
          UserRole.client => '/client/dashboard',
        };
      }

      if (authState.isAuthenticated) {
        final role = authState.user!.role;
        final prefix = switch (role) {
          UserRole.admin => '/admin',
          UserRole.employee => '/employee',
          UserRole.client => '/client',
        };
        if (!location.startsWith(prefix)) {
          return '$prefix/dashboard';
        }
      }

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),

      GoRoute(
        path: '/admin/employees/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => EmployeeDetailScreen(
          employeeId: state.pathParameters['id']!,
          employeeName: state.uri.queryParameters['name'] ?? '',
        ),
      ),

      GoRoute(
        path: '/admin/collection-invoices',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const CollectionInvoicesScreen(),
      ),

      GoRoute(
        path: '/admin/damaged-stock',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const DamagedStockScreen(),
      ),

      GoRoute(
        path: '/admin/suppliers/:id/stock',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => SupplierStockScreen(
          supplierId: state.pathParameters['id']!,
          supplierName: state.uri.queryParameters['name'] ?? '',
        ),
      ),

      GoRoute(
        path: '/admin/clients/:id/statement',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => AccountStatementScreen(
          entityId: state.pathParameters['id']!,
          entityName: state.uri.queryParameters['name'] ?? '',
          kind: AccountStatementKind.client,
        ),
      ),

      GoRoute(
        path: '/admin/suppliers/:id/statement',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => AccountStatementScreen(
          entityId: state.pathParameters['id']!,
          entityName: state.uri.queryParameters['name'] ?? '',
          kind: AccountStatementKind.supplier,
        ),
      ),

      GoRoute(
        path: '/employee/suppliers/:id/stock',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => SupplierStockScreen(
          supplierId: state.pathParameters['id']!,
          supplierName: state.uri.queryParameters['name'] ?? '',
        ),
      ),

      GoRoute(
        path: '/employee/suppliers/:id/statement',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => AccountStatementScreen(
          entityId: state.pathParameters['id']!,
          entityName: state.uri.queryParameters['name'] ?? '',
          kind: AccountStatementKind.supplier,
        ),
      ),

      ShellRoute(
        navigatorKey: adminShellNavigatorKey,
        builder: (context, state, child) => AppShell(
          basePath: '/admin',
          navigationItems: const [
            (icon: Icons.dashboard, path: '/admin/dashboard'),
            (icon: Icons.receipt_long, path: '/admin/invoices'),
            (icon: Icons.account_balance_wallet, path: '/admin/treasury'),
            (icon: Icons.people, path: '/admin/clients'),
            (icon: Icons.local_shipping, path: '/admin/suppliers'),
            (icon: Icons.settings, path: '/admin/settings'),
          ],
          child: child,
        ),
        routes: [
          GoRoute(path: '/admin/dashboard', builder: (_, __) => const AdminDashboardScreen()),
          GoRoute(path: '/admin/treasury', builder: (_, __) => const AdminTreasuryScreen()),
          GoRoute(path: '/admin/invoices', builder: (_, __) => const InvoicesListScreen(basePath: '/admin')),
          GoRoute(
            path: '/admin/invoices/create',
            builder: (_, __) => const CreateInvoiceScreen(basePath: '/admin'),
          ),
          GoRoute(
            path: '/admin/invoices/:id/edit',
            builder: (_, state) => EditInvoiceScreen(invoiceId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/admin/invoices/:id',
            builder: (_, state) => InvoiceDetailScreen(invoiceId: state.pathParameters['id']!, basePath: '/admin'),
          ),
          GoRoute(path: '/admin/stock', builder: (_, __) => const StockScreen()),
          GoRoute(path: '/admin/clients', builder: (_, __) => const ClientsScreen()),
          GoRoute(path: '/admin/suppliers', builder: (_, __) => const SuppliersScreen(basePath: '/admin')),
          GoRoute(path: '/admin/reports', builder: (_, __) => const ReportsScreen()),
          GoRoute(path: '/admin/employees', builder: (_, __) => const EmployeesScreen()),
          GoRoute(path: '/admin/settings', builder: (_, __) => const SettingsScreen()),
        ],
      ),

      GoRoute(
        path: '/employee/treasury/statement',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const EmployeeTreasuryStatementScreen(),
      ),

      ShellRoute(
        navigatorKey: employeeShellNavigatorKey,
        builder: (context, state, child) => AppShell(
          basePath: '/employee',
          navigationItems: const [
            (icon: Icons.dashboard, path: '/employee/dashboard'),
            (icon: Icons.receipt_long, path: '/employee/invoices'),
            (icon: Icons.payments, path: '/employee/collection-invoices'),
            (icon: Icons.local_shipping, path: '/employee/suppliers'),
            (icon: Icons.settings, path: '/employee/settings'),
          ],
          child: child,
        ),
        routes: [
          GoRoute(path: '/employee/dashboard', builder: (_, __) => const EmployeeDashboardScreen()),
          GoRoute(
            path: '/employee/collection-invoices',
            builder: (_, __) => const CollectionInvoicesScreen(),
          ),
          GoRoute(path: '/employee/invoices', builder: (_, __) => const InvoicesListScreen(basePath: '/employee')),
          GoRoute(
            path: '/employee/invoices/create',
            builder: (_, __) => const CreateInvoiceScreen(basePath: '/employee'),
          ),
          GoRoute(
            path: '/employee/invoices/:id',
            builder: (_, state) => InvoiceDetailScreen(invoiceId: state.pathParameters['id']!, basePath: '/employee'),
          ),
          GoRoute(
            path: '/employee/suppliers',
            builder: (_, __) => const SuppliersScreen(basePath: '/employee'),
          ),
          GoRoute(path: '/employee/settings', builder: (_, __) => const SettingsScreen()),
        ],
      ),

      ShellRoute(
        navigatorKey: clientShellNavigatorKey,
        builder: (context, state, child) => AppShell(
          basePath: '/client',
          navigationItems: const [
            (icon: Icons.dashboard, path: '/client/dashboard'),
            (icon: Icons.receipt_long, path: '/client/invoices'),
            (icon: Icons.settings, path: '/client/settings'),
          ],
          child: child,
        ),
        routes: [
          GoRoute(path: '/client/dashboard', builder: (_, __) => const ClientDashboardScreen()),
          GoRoute(path: '/client/invoices', builder: (_, __) => const InvoicesListScreen(basePath: '/client')),
          GoRoute(
            path: '/client/invoices/:id',
            builder: (_, state) => InvoiceDetailScreen(invoiceId: state.pathParameters['id']!, basePath: '/client'),
          ),
          GoRoute(path: '/client/settings', builder: (_, __) => const SettingsScreen()),
        ],
      ),
    ],
  );
});
