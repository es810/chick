import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/api_error.dart';
import '../../../services/api_client.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/loading_widget.dart';

class EmployeesScreen extends ConsumerStatefulWidget {
  const EmployeesScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends ConsumerState<EmployeesScreen> {
  List<Map<String, dynamic>> _employees = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ref.read(apiClientProvider).get('/employees');
      final data = response.data as Map<String, dynamic>;
      setState(() {
        _employees = (data['data'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error = apiErrorMessage(e);
        _loading = false;
      });
    }
  }

  void _openLedger(Map<String, dynamic> emp) {
    final id = (emp['_id'] ?? emp['id']).toString();
    final name = emp['name'] as String;
    context.push(
      '/admin/employees/$id?name=${Uri.encodeQueryComponent(name)}',
    );
  }

  Future<void> _showEmployeeFormDialog({Map<String, dynamic>? employee}) async {
    final l10n = context.l10n;
    final isEdit = employee != null;
    final nameController = TextEditingController(text: employee?['name'] as String? ?? '');
    final phoneController = TextEditingController(text: employee?['phone'] as String? ?? '');
    final emailController = TextEditingController(text: employee?['email'] as String? ?? '');
    final passwordController = TextEditingController();
    final salaryController = TextEditingController(
      text: employee != null ? ((employee['salary'] as num?)?.toString() ?? '') : '',
    );
    var isActive = employee?['isActive'] as bool? ?? true;
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? l10n.editEmployee : l10n.addEmployee),
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
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: l10n.email,
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return l10n.fieldRequired;
                      if (!v.contains('@')) return l10n.invalidEmail;
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: salaryController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: l10n.salary,
                      prefixIcon: const Icon(Icons.payments_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return l10n.fieldRequired;
                      if (double.tryParse(v.trim()) == null) return l10n.invalidAmount;
                      if (double.parse(v.trim()) < 0) return l10n.invalidAmount;
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
                      if (!isEdit && (v == null || v.length < 6)) {
                        return l10n.minPassword;
                      }
                      if (isEdit && v != null && v.isNotEmpty && v.length < 6) {
                        return l10n.minPassword;
                      }
                      return null;
                    },
                  ),
                  if (isEdit) ...[
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.employeeActive),
                      value: isActive,
                      onChanged: (v) => setDialogState(() => isActive = v),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
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
      ),
    );

    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text;
    final salaryText = salaryController.text.trim();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameController.dispose();
      phoneController.dispose();
      emailController.dispose();
      passwordController.dispose();
      salaryController.dispose();
    });

    if (ok != true || !mounted) return;

    final api = ref.read(apiClientProvider);
    final body = <String, dynamic>{
      'name': name,
      'phone': phone,
      'email': email,
      'salary': double.parse(salaryText),
    };
    if (password.isNotEmpty) {
      body['password'] = password;
    }
    if (isEdit) body['isActive'] = isActive;

    try {
      if (isEdit) {
        final id = (employee['_id'] ?? employee['id']).toString();
        await api.put('/employees/$id', data: body);
      } else {
        if (!body.containsKey('password')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.minPassword), backgroundColor: AppColors.error),
            );
          }
          return;
        }
        await api.post('/employees', data: body);
      }

      await _loadEmployees();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit ? l10n.employeeUpdated : l10n.employeeAdded),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              apiErrorMessage(
                e,
                fallback: isEdit ? l10n.employeeUpdateFailed : l10n.employeeAddFailed,
              ),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteEmployee(Map<String, dynamic> emp) async {
    final l10n = context.l10n;
    final name = emp['name'] as String;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.confirmDeleteEmployee),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final id = (emp['_id'] ?? emp['id']).toString();
      await ref.read(apiClientProvider).delete('/employees/$id');
      await _loadEmployees();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.employeeDeleted} ($name)'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(apiErrorMessage(e, fallback: l10n.employeeDeleteFailed)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildList() {
    final l10n = context.l10n;

    if (_loading) {
      return const LoadingShimmer();
    }
    if (_error != null) {
      return ErrorStateWidget(message: _error!, onRetry: _loadEmployees);
    }
    if (_employees.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.people,
        title: l10n.noEmployees,
        action: ElevatedButton.icon(
          onPressed: () => _showEmployeeFormDialog(),
          icon: const Icon(Icons.person_add),
          label: Text(l10n.addEmployee),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEmployees,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _employees.length,
        itemBuilder: (_, i) {
          final emp = _employees[i];
          final isActive = emp['isActive'] as bool? ?? true;
          final name = emp['name'] as String;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              onTap: () => _openLedger(emp),
              leading: CircleAvatar(
                backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.15),
                child: Text(name[0].toUpperCase()),
              ),
              title: Text(
                name,
                style: TextStyle(
                  decoration: isActive ? null : TextDecoration.lineThrough,
                  color: isActive ? null : Colors.grey,
                ),
              ),
              subtitle: Text(
                '${emp['email']}\n${emp['phone']}\n${l10n.salary}: ${context.formatCurrency(((emp['salary'] as num?) ?? 0).toDouble())}',
              ),
              isThreeLine: true,
              trailing: PopupMenuButton<String>(
                onSelected: (action) {
                  switch (action) {
                    case 'ledger':
                      _openLedger(emp);
                    case 'edit':
                      _showEmployeeFormDialog(employee: emp);
                    case 'delete':
                      _confirmDeleteEmployee(emp);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'ledger',
                    child: ListTile(
                      leading: const Icon(Icons.account_balance_wallet_outlined),
                      title: Text(l10n.viewLedger),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: Text(l10n.editEmployee),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: const Icon(Icons.delete_outline, color: AppColors.error),
                      title: Text(l10n.delete, style: const TextStyle(color: AppColors.error)),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (widget.embedded) {
      return ColoredBox(
        color: const Color(0xFF0D1B3E),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.employeesTreasury,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _showEmployeeFormDialog(),
                    icon: const Icon(Icons.person_add, color: Colors.white),
                    tooltip: l10n.addEmployee,
                  ),
                  IconButton(
                    onPressed: _loadEmployees,
                    icon: const Icon(Icons.refresh, color: Colors.white70),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildList()),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.employees),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => _showEmployeeFormDialog(),
            tooltip: l10n.addEmployee,
          ),
        ],
      ),
      body: _buildList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEmployeeFormDialog(),
        tooltip: l10n.addEmployee,
        child: const Icon(Icons.person_add),
      ),
    );
  }
}
