import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/api_error.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../models/supplier_model.dart';
import '../../../models/user_model.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/role_hint_banner.dart';

class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key, this.basePath = '/admin'});

  final String basePath;

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  bool _isAdmin() => ref.read(currentUserProvider)?.role == UserRole.admin;

  bool _canAddSupplier() {
    final role = ref.read(currentUserProvider)?.role;
    return role == UserRole.admin || role == UserRole.employee;
  }

  void _openSupplierStock(SupplierModel supplier) {
    context.push(
      '${widget.basePath}/suppliers/${supplier.id}/stock?name=${Uri.encodeComponent(supplier.name)}',
    );
  }

  void _openSupplierStatement(SupplierModel supplier) {
    context.push(
      '${widget.basePath}/suppliers/${supplier.id}/statement?name=${Uri.encodeComponent(supplier.name)}',
    );
  }

  Future<void> _showSupplierDialog({SupplierModel? supplier}) async {
    final l10n = context.l10n;
    final isEdit = supplier != null;
    final nameController = TextEditingController(text: supplier?.name ?? '');
    final locationController = TextEditingController(text: supplier?.location ?? '');
    final phoneController = TextEditingController(text: supplier?.phone ?? '');
    final balanceController = TextEditingController(
      text: supplier != null ? supplier.balance.toStringAsFixed(0) : '',
    );
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? l10n.editSupplier : l10n.addSupplier),
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
                  controller: locationController,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    labelText: l10n.stockLocation,
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
                    labelText: l10n.supplierDebt,
                    prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    if (double.tryParse(v.trim()) == null) return l10n.invalidAmount;
                    if (double.parse(v.trim()) < 0) return l10n.invalidAmount;
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

    try {
      final repo = ref.read(supplierRepositoryProvider);
      if (isEdit) {
        await repo.updateSupplier(supplier.id, {
          'name': nameController.text.trim(),
          'location': locationController.text.trim(),
          'phone': phoneController.text.trim(),
          'balance': balance,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.supplierUpdated)));
        }
      } else {
        final created = await repo.createSupplier(
          SupplierModel(
            id: '',
            name: nameController.text.trim(),
            location: locationController.text.trim(),
            phone: phoneController.text.trim(),
            balance: balance,
          ),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.supplierAdded)));
          _openSupplierStock(created);
        }
      }
      ref.invalidate(suppliersProvider);
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e))),
        );
      }
    }
  }

  Future<void> _confirmDelete(SupplierModel supplier) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.confirmDeleteSupplier),
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
      await ref.read(supplierRepositoryProvider).deleteSupplier(supplier.id);
      ref.invalidate(suppliersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.supplierDeleted)));
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
    final suppliersAsync = ref.watch(suppliersProvider);
    final isAdmin = _isAdmin();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.suppliers),
        actions: [
          if (_canAddSupplier())
            IconButton(
              icon: const Icon(Icons.add_business),
              tooltip: l10n.addSupplier,
              onPressed: () => _showSupplierDialog(),
            ),
        ],
      ),
      body: Column(
        children: [
          RoleHintBanner(text: l10n.suppliersRoleHint),
          Expanded(
            child: suppliersAsync.when(
              loading: () => const LoadingShimmer(),
              error: (e, _) => ErrorStateWidget(
                message: apiErrorMessage(
                  e,
                  fallback: e is DioException && e.response?.statusCode == 401
                      ? l10n.sessionExpired
                      : l10n.serverError,
                ),
                onRetry: () => ref.invalidate(suppliersProvider),
              ),
              data: (suppliers) {
                if (suppliers.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.local_shipping,
                    title: l10n.noSuppliersYet,
                    action: _canAddSupplier()
                        ? ElevatedButton.icon(
                            onPressed: () => _showSupplierDialog(),
                            icon: const Icon(Icons.add_business),
                            label: Text(l10n.addSupplier),
                          )
                        : null,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(suppliersProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: suppliers.length,
                    itemBuilder: (_, i) {
                      final supplier = suppliers[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(child: Text(supplier.name[0].toUpperCase())),
                          title: Text(supplier.name),
                          subtitle: Text(
                            '${supplier.phone}\n${supplier.location.isNotEmpty ? supplier.location : '—'}',
                          ),
                          isThreeLine: true,
                          trailing: isAdmin
                              ? PopupMenuButton<String>(
                                  onSelected: (action) {
                                    if (action == 'stock') {
                                      _openSupplierStock(supplier);
                                    } else if (action == 'statement') {
                                      _openSupplierStatement(supplier);
                                    } else if (action == 'edit') {
                                      _showSupplierDialog(supplier: supplier);
                                    } else if (action == 'delete') {
                                      _confirmDelete(supplier);
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    PopupMenuItem(value: 'stock', child: Text(l10n.supplierStock)),
                                    PopupMenuItem(value: 'statement', child: Text(l10n.accountStatement)),
                                    PopupMenuItem(value: 'edit', child: Text(l10n.editSupplier)),
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
                                          context.formatCurrency(supplier.balance),
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                        const Icon(Icons.more_vert, size: 18),
                                      ],
                                    ),
                                  ),
                                )
                              : PopupMenuButton<String>(
                                  onSelected: (action) {
                                    if (action == 'stock') {
                                      _openSupplierStock(supplier);
                                    } else if (action == 'statement') {
                                      _openSupplierStatement(supplier);
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    PopupMenuItem(value: 'stock', child: Text(l10n.supplierStock)),
                                    PopupMenuItem(
                                      value: 'statement',
                                      child: Text(l10n.accountStatement),
                                    ),
                                  ],
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          context.formatCurrency(supplier.balance),
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                        const Icon(Icons.more_vert, size: 18),
                                      ],
                                    ),
                                  ),
                                ),
                          onTap: () => _openSupplierStock(supplier),
                          onLongPress: () => _openSupplierStatement(supplier),
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
