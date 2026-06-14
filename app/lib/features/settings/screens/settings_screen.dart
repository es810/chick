import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_version.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../models/user_model.dart';
import '../../../services/sync_service.dart';
import '../../../services/storage_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final user = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          if (user != null)
            UserAccountsDrawerHeader(
              accountName: Text(user.name),
              accountEmail: Text(user.email),
              currentAccountPicture: CircleAvatar(
                child: Text(user.name[0].toUpperCase()),
              ),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
            ),
          ListTile(
            leading: const Icon(Icons.badge),
            title: Text(l10n.role),
            subtitle: Text(user != null ? l10n.roleLabel(user.role.name) : ''),
          ),
          if (user?.role == UserRole.employee)
            ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: Text(l10n.mySalary),
              subtitle: Text(context.formatCurrency(user!.salary)),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.language),
            subtitle: Text(locale.languageCode == 'ar' ? l10n.arabic : l10n.english),
            trailing: DropdownButton<String>(
              value: locale.languageCode,
              items: [
                DropdownMenuItem(value: 'en', child: Text(l10n.english)),
                DropdownMenuItem(value: 'ar', child: Text(l10n.arabic)),
              ],
              onChanged: (v) {
                if (v != null) ref.read(localeProvider.notifier).setLocale(v);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: Text(l10n.theme),
            subtitle: Text(_themeLabel(l10n, themeMode)),
            trailing: DropdownButton<String>(
              value: themeMode,
              items: [
                DropdownMenuItem(value: 'system', child: Text(l10n.system)),
                DropdownMenuItem(value: 'light', child: Text(l10n.light)),
                DropdownMenuItem(value: 'dark', child: Text(l10n.dark)),
              ],
              onChanged: (v) async {
                if (v != null) {
                  ref.read(themeModeProvider.notifier).state = v;
                  await ref.read(storageServiceProvider).setThemeMode(v);
                }
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: Text(l10n.syncPending),
            subtitle: Text(l10n.syncSubtitle),
            onTap: () async {
              final count = await ref.read(syncServiceProvider).syncPending();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(count > 0 ? l10n.syncedItems(count) : l10n.nothingToSync),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: Text(l10n.pushNotifications),
            subtitle: Text(l10n.lowStockAlertsEnabled),
            trailing: Switch(value: true, onChanged: (_) {}),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.appVersion),
            subtitle: Text(AppVersion.label),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text(l10n.logout, style: const TextStyle(color: Colors.red)),
            onTap: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
    );
  }

  String _themeLabel(AppLocalizations l10n, String mode) {
    switch (mode) {
      case 'light':
        return l10n.light;
      case 'dark':
        return l10n.dark;
      default:
        return l10n.system;
    }
  }
}
