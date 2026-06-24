import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/api_error.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../models/client_model.dart';
import '../../../models/user_model.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/role_hint_banner.dart';

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  bool _isAdmin() => ref.read(currentUserProvider)?.role == UserRole.admin;

  Future<void> _showClientDialog({ClientModel? client}) async {
    final l10n = context.l10n;
    final isEdit = client != null;
    final nameController = TextEditingController(text: client?.name ?? '');
    final phoneController = TextEditingController(text: client?.phone ?? '');
    final addressController = TextEditingController(text: client?.address ?? '');
    final balanceController = TextEditingController(
      text: client != null ? client.balance.toStringAsFixed(0) : '',
    );
    final emailController = TextEditingController(text: client?.email ?? '');
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? l10n.editClient : l10n.addClient),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    labelText: l10n.name,
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? l10n.fieldRequired : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: addressController,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    labelText: l10n.address,
                    prefixIcon: const Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: l10n.phone,
                    prefixIcon: const Icon(Icons.phone_outlined),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? l10n.fieldRequired : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: balanceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: l10n.clientDebt,
                    prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    if (double.tryParse(v.trim()) == null) return l10n.invalidAmount;
                    if (double.parse(v.trim()) < 0) return l10n.invalidAmount;
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: l10n.loginId,
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return l10n.fieldRequired;
                    if (!v.contains('@')) return l10n.invalidEmail;
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: isEdit ? l10n.newPasswordOptional : l10n.password,
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                  validator: (v) {
                    if (!isEdit && (v == null || v.length < 6)) return l10n.minPassword;
                    if (isEdit && v != null && v.isNotEmpty && v.length < 6) {
                      return l10n.minPassword;
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, true);
              }
            },
            child: Text(isEdit ? l10n.save : l10n.add),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    final balance = double.tryParse(balanceController.text.trim()) ?? 0;
    final password = passwordController.text;

    try {
      final repo = ref.read(clientRepositoryProvider);
      if (isEdit) {
        final updates = <String, dynamic>{
          'name': nameController.text.trim(),
          'phone': phoneController.text.trim(),
          'address': addressController.text.trim(),
          'balance': balance,
          'email': emailController.text.trim(),
        };
        if (password.isNotEmpty) updates['password'] = password;
        await repo.updateClient(client.id, updates);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.clientUpdated)));
        }
      } else {
        await repo.createClient(
          ClientModel(
            id: '',
            name: nameController.text.trim(),
            phone: phoneController.text.trim(),
            address: addressController.text.trim(),
            balance: balance,
            email: emailController.text.trim(),
          ),
          password: password,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.clientAdded)));
        }
      }
      ref.invalidate(clientsProvider);
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e))),
        );
      }
    }
  }

  Future<void> _confirmDelete(ClientModel client) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.confirmDeleteClient),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await ref.read(clientRepositoryProvider).deleteClient(client.id);
      ref.invalidate(clientsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.clientDeleted)));
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final clientsAsync = ref.watch(clientsProvider);
    final isAdmin = _isAdmin();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.clients),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.person_add),
              tooltip: l10n.addClient,
              onPressed: () => _showClientDialog(),
            ),
        ],
      ),
      body: Column(
        children: [
          RoleHintBanner(text: l10n.clientsRoleHint),
          Expanded(
            child: clientsAsync.when(
              loading: () => const LoadingShimmer(),
              error: (e, _) => ErrorStateWidget(
                message: apiErrorMessage(
                  e,
                  fallback: e is DioException && e.response?.statusCode == 401
                      ? l10n.sessionExpired
                      : l10n.serverError,
                ),
                onRetry: () => ref.invalidate(clientsProvider),
              ),
              data: (clients) {
                if (clients.isEmpty) {
                  return EmptyStateWidget(icon: Icons.people, title: l10n.noClientsYet);
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(clientsProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: clients.length,
                    itemBuilder: (_, i) {
                      final client = clients[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(child: Text(client.name[0].toUpperCase())),
                          title: Text(client.name),
                          subtitle: Text(
                            '${client.phone}\n${client.address.isNotEmpty ? client.address : '—'}'
                            '${client.email.isNotEmpty ? '\n${client.email}' : ''}',
                          ),
                          isThreeLine: true,
                          trailing: isAdmin
                              ? PopupMenuButton<String>(
                                  onSelected: (action) {
                                    if (action == 'edit') {
                                      _showClientDialog(client: client);
                                    } else if (action == 'delete') {
                                      _confirmDelete(client);
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    PopupMenuItem(value: 'edit', child: Text(l10n.editClient)),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          context.formatCurrency(client.balance),
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                        const Icon(Icons.more_vert, size: 18),
                                      ],
                                    ),
                                  ),
                                )
                              : Text(
                                  context.formatCurrency(client.balance),
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                          onTap: isAdmin ? () => _showClientDialog(client: client) : null,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
