import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/api_error.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../models/client_model.dart';
import '../../../models/treasury_entry_item.dart';
import '../../../models/user_model.dart';
import '../../../shared/widgets/client_picker_field.dart';

Future<bool?> showCollectionInvoiceDialog({
  required BuildContext context,
  required WidgetRef ref,
  TreasuryEntryItem? existing,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => _CollectionInvoiceDialog(existing: existing),
  );
}

class _CollectionInvoiceDialog extends ConsumerStatefulWidget {
  const _CollectionInvoiceDialog({this.existing});

  final TreasuryEntryItem? existing;

  @override
  ConsumerState<_CollectionInvoiceDialog> createState() => _CollectionInvoiceDialogState();
}

class _CollectionInvoiceDialogState extends ConsumerState<_CollectionInvoiceDialog> {
  ClientModel? _selectedClient;
  String? _selectedEmployeeId;
  late DateTime _collectionDate;
  final _amountPaidController = TextEditingController();
  final _amountDeductedController = TextEditingController();
  final _balanceBeforeController = TextEditingController();

  List<ClientModel> _clients = [];
  List<Map<String, dynamic>> _employees = [];
  bool _loadingData = true;
  String? _dataError;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final now = DateTime.now();
    _collectionDate = existing?.collectionDate ??
        DateTime(now.year, now.month, now.day);

    if (existing != null) {
      _selectedEmployeeId = existing.employeeId;
      _amountPaidController.text = existing.amountPaid?.toStringAsFixed(2) ?? '';
      _amountDeductedController.text = existing.amountDeducted?.toStringAsFixed(2) ?? '';
      _balanceBeforeController.text = existing.balanceBefore?.toStringAsFixed(2) ?? '';
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  void _bootstrap() {
    if (!mounted) return;

    if (widget.existing == null) {
      final user = ref.read(currentUserProvider);
      if (user?.role == UserRole.employee) {
        setState(() => _selectedEmployeeId = user!.id);
      }
    }

    _loadFormData();
  }

  Future<void> _loadFormData() async {
    try {
      ref.invalidate(clientsProvider);
      final results = await Future.wait([
        ref.read(clientsProvider.future),
        ref.read(collectionRepositoryProvider).listEmployees(),
      ]);
      if (!mounted) return;

      final clients = results[0] as List<ClientModel>;
      final employees = results[1] as List<Map<String, dynamic>>;
      ClientModel? selectedClient;
      if (widget.existing?.clientId != null) {
        selectedClient =
            clients.where((c) => c.id == widget.existing!.clientId).firstOrNull;
      }

      setState(() {
        _clients = clients;
        _employees = employees;
        _selectedClient = selectedClient;
        _loadingData = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _dataError = apiErrorMessage(e);
          _loadingData = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _amountPaidController.dispose();
    _amountDeductedController.dispose();
    _balanceBeforeController.dispose();
    super.dispose();
  }

  double get _balanceBefore =>
      double.tryParse(_balanceBeforeController.text.trim().replaceAll(',', '')) ?? 0;

  double get _amountPaid =>
      double.tryParse(_amountPaidController.text.trim().replaceAll(',', '')) ?? 0;

  double get _amountDeducted =>
      double.tryParse(_amountDeductedController.text.trim().replaceAll(',', '')) ?? 0;

  double get _balanceAfter =>
      (_balanceBefore - _amountPaid - _amountDeducted).clamp(0, double.infinity);

  void _onClientSelected(ClientModel? client) {
    setState(() {
      _selectedClient = client;
      if (widget.existing == null && client != null) {
        _balanceBeforeController.text = client.balance.toStringAsFixed(2);
        _amountPaidController.clear();
        _amountDeductedController.clear();
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _collectionDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(
        () => _collectionDate = DateTime(picked.year, picked.month, picked.day),
      );
    }
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    if (_selectedClient == null) {
      _showError(l10n.selectClientRequired);
      return;
    }
    if (_selectedEmployeeId == null) {
      _showError(l10n.selectCollector);
      return;
    }

    final amountPaid = double.tryParse(_amountPaidController.text.trim().replaceAll(',', ''));
    if (amountPaid == null || amountPaid <= 0) {
      _showError(l10n.invalidAmount);
      return;
    }
    if (_amountDeducted < 0) {
      _showError(l10n.invalidAmount);
      return;
    }
    if (amountPaid + _amountDeducted > _balanceBefore) {
      _showError(l10n.paymentExceedsBalance);
      return;
    }

    setState(() => _submitting = true);
    try {
      final clients = await ref.read(clientRepositoryProvider).getClients();
      final freshClient = clients.firstWhere((c) => c.id == _selectedClient!.id);
      _selectedClient = freshClient;
      _balanceBeforeController.text = freshClient.balance.toStringAsFixed(2);

      final repo = ref.read(collectionRepositoryProvider);
      final body = {
        'clientId': _selectedClient!.id,
        'employeeId': _selectedEmployeeId!,
        'collectionDate': _collectionDate,
        'amountPaid': amountPaid,
        'amountDeducted': _amountDeducted,
        'balanceBefore': _balanceBefore,
        'balanceAfter': _balanceAfter,
      };

      if (widget.existing == null) {
        await repo.createInvoice(
          clientId: body['clientId'] as String,
          employeeId: body['employeeId'] as String,
          collectionDate: body['collectionDate'] as DateTime,
          amountPaid: body['amountPaid'] as double,
          amountDeducted: body['amountDeducted'] as double,
          balanceBefore: body['balanceBefore'] as double,
          balanceAfter: body['balanceAfter'] as double,
        );
      } else {
        await repo.updateInvoice(
          id: widget.existing!.id,
          clientId: body['clientId'] as String,
          employeeId: body['employeeId'] as String,
          collectionDate: body['collectionDate'] as DateTime,
          amountPaid: body['amountPaid'] as double,
          amountDeducted: body['amountDeducted'] as double,
          balanceBefore: body['balanceBefore'] as double,
          balanceAfter: body['balanceAfter'] as double,
        );
      }

      ref.invalidate(clientsProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(treasurySummaryProvider);
      ref.invalidate(myTreasuryProvider);
      ref.invalidate(myTreasuryStatementProvider);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _showError(apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Widget _buildForm(AppLocalizations l10n, bool isEmployee) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClientPickerField(
          clients: _clients,
          selected: _selectedClient,
          showPhone: false,
          onSelected: _onClientSelected,
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _pickDate,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: l10n.date,
              suffixIcon: const Icon(Icons.calendar_today),
            ),
            child: Text(DateFormat.yMMMd().format(_collectionDate)),
          ),
        ),
        const SizedBox(height: 12),
        if (isEmployee)
          InputDecorator(
            decoration: InputDecoration(labelText: l10n.collectorEmployee),
            child: Text(
              _employees
                      .where((e) => (e['_id'] ?? e['id']).toString() == _selectedEmployeeId)
                      .map((e) => e['name'] as String? ?? '')
                      .firstOrNull ??
                  ref.read(currentUserProvider)?.name ??
                  '',
            ),
          )
        else
          DropdownButtonFormField<String>(
            key: ValueKey(_selectedEmployeeId ?? 'employee'),
            initialValue: _selectedEmployeeId,
            decoration: InputDecoration(labelText: l10n.selectCollector),
            items: _employees
                .map(
                  (e) => DropdownMenuItem<String>(
                    value: (e['_id'] ?? e['id']).toString(),
                    child: Text(e['name'] as String? ?? ''),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _selectedEmployeeId = v),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _balanceBeforeController,
          readOnly: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: l10n.balanceBeforePayment,
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('collection_amount_paid'),
          controller: _amountPaidController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofillHints: const [],
          enableSuggestions: false,
          autocorrect: false,
          decoration: InputDecoration(labelText: l10n.amountPaid),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('collection_amount_discount'),
          controller: _amountDeductedController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofillHints: const [],
          enableSuggestions: false,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: l10n.amountDeducted,
            helperText: l10n.discountOptionalHint,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        InputDecorator(
          decoration: InputDecoration(labelText: l10n.balanceAfterPayment),
          child: Text(
            _balanceAfter.toStringAsFixed(2),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isEmployee = ref.read(currentUserProvider)?.role == UserRole.employee;

    Widget content;
    if (_loadingData) {
      content = const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_dataError != null) {
      content = Text(_dataError!);
    } else {
      content = _buildForm(l10n, isEmployee);
    }

    return AlertDialog(
      title: Text(widget.existing == null ? l10n.collectionInvoice : l10n.editEntry),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(child: content),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: _submitting || _loadingData ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(l10n.save),
        ),
      ],
    );
  }
}
