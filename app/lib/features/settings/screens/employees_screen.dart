import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
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
        _employees = (data['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data?['message']?.toString() ?? e.message;
        _loading = false;
      });
    }
  }

  void _showAddDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController(text: 'employee123');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.addEmployee),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone')),
              TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
              TextField(controller: passwordController, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(apiClientProvider).post('/employees', data: {
                'name': nameController.text,
                'phone': phoneController.text,
                'email': emailController.text,
                'password': passwordController.text,
              });
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _loadEmployees();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
          ? const LoadingShimmer()
          : _error != null
              ? ErrorStateWidget(message: _error!, onRetry: _loadEmployees)
              : _employees.isEmpty
                  ? EmptyStateWidget(icon: Icons.people, title: context.l10n.noEmployees)
                  : RefreshIndicator(
                      onRefresh: _loadEmployees,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _employees.length,
                        itemBuilder: (_, i) {
                          final emp = _employees[i];
                          final isActive = emp['isActive'] as bool? ?? true;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              onTap: () {
                                final id = emp['_id'] as String;
                                final name = emp['name'] as String;
                                context.push(
                                  '/admin/employees/$id?name=${Uri.encodeQueryComponent(name)}',
                                );
                              },
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.15),
                                child: Text((emp['name'] as String)[0].toUpperCase()),
                              ),
                              title: Text(emp['name'] as String),
                              subtitle: Text('${emp['email']}\n${emp['phone']}'),
                              isThreeLine: true,
                              trailing: Icon(
                                isActive ? Icons.check_circle : Icons.cancel,
                                color: isActive ? AppColors.success : AppColors.error,
                              ),
                            ),
                          );
                        },
                      ),
                    );

    if (widget.embedded) {
      return ColoredBox(color: const Color(0xFF0D1B3E), child: body);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.employees),
        actions: [
          IconButton(icon: const Icon(Icons.person_add), onPressed: _showAddDialog),
        ],
      ),
      body: body,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.person_add),
      ),
    );
  }
}
