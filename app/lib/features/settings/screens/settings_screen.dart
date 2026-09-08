import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_version.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/api_error.dart';
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
    final isAdmin = user?.role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          if (user != null)
            UserAccountsDrawerHeader(
              accountName: Text(user.name),
              accountEmail: Text(user.email),
              currentAccountPicture: CircleAvatar(
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                ),
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
          if (isAdmin && user != null) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(l10n.editName),
              subtitle: Text(user.name),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _editName(context, ref, user),
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: Text(l10n.changePassword),
              subtitle: Text(l10n.changePasswordSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _changePassword(context, ref),
            ),
          ],
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

  Future<void> _editName(BuildContext context, WidgetRef ref, UserModel user) async {
    final l10n = context.l10n;
    final controller = TextEditingController(text: user.name);
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.editName),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(labelText: l10n.name),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return l10n.nameRequired;
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.pop(ctx, true);
            },
            child: Text(l10n.saveChanges),
          ),
        ],
      ),
    );

    final name = controller.text.trim();
    controller.dispose();
    if (saved != true || !context.mounted) return;
    if (name == user.name) return;

    try {
      await ref.read(authProvider.notifier).updateProfile(name: name);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profileUpdated), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(apiErrorMessage(e, fallback: l10n.serverError)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var obscureCurrent = true;
    var obscureNew = true;
    var obscureConfirm = true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(l10n.changePassword),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: currentController,
                    obscureText: obscureCurrent,
                    decoration: InputDecoration(
                      labelText: l10n.currentPassword,
                      suffixIcon: IconButton(
                        icon: Icon(obscureCurrent ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setLocal(() => obscureCurrent = !obscureCurrent),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return l10n.currentPasswordRequired;
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: newController,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: l10n.newPassword,
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setLocal(() => obscureNew = !obscureNew),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.length < 6) return l10n.minPassword;
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmController,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: l10n.confirmPassword,
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirm ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setLocal(() => obscureConfirm = !obscureConfirm),
                      ),
                    ),
                    validator: (v) {
                      if (v != newController.text) return l10n.passwordsDoNotMatch;
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) return;
                Navigator.pop(ctx, true);
              },
              child: Text(l10n.saveChanges),
            ),
          ],
        ),
      ),
    );

    final currentPassword = currentController.text;
    final newPassword = newController.text;
    currentController.dispose();
    newController.dispose();
    confirmController.dispose();
    if (saved != true || !context.mounted) return;

    try {
      await ref.read(authProvider.notifier).updateProfile(
            currentPassword: currentPassword,
            newPassword: newPassword,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.passwordUpdated), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(apiErrorMessage(e, fallback: l10n.serverError)),
          backgroundColor: AppColors.error,
        ),
      );
    }
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
