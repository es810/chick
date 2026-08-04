import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../models/client_model.dart';

/// Searchable client selector — tap to open a sheet and filter by name/phone.
class ClientPickerField extends StatelessWidget {
  const ClientPickerField({
    super.key,
    required this.clients,
    required this.selected,
    required this.onSelected,
    this.showPhone = true,
  });

  final List<ClientModel> clients;
  final ClientModel? selected;
  final ValueChanged<ClientModel?> onSelected;
  final bool showPhone;

  Future<void> _openPicker(BuildContext context) async {
    final l10n = context.l10n;
    final result = await showModalBottomSheet<ClientModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _ClientSearchSheet(
        clients: clients,
        selectedId: selected?.id,
        showPhone: showPhone,
        title: l10n.selectClient,
        searchHint: l10n.searchClients,
        emptyLabel: l10n.noClientsMatch,
      ),
    );
    if (result != null) {
      onSelected(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = selected == null
        ? null
        : showPhone
            ? '${selected!.name} (${selected!.phone})'
            : selected!.name;

    return InkWell(
      onTap: () => _openPicker(context),
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: l10n.selectClient,
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected != null)
                IconButton(
                  tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                  icon: const Icon(Icons.clear),
                  onPressed: () => onSelected(null),
                ),
              const Icon(Icons.search),
              const SizedBox(width: 8),
            ],
          ),
        ),
        isEmpty: selected == null,
        child: Text(
          label ?? '',
          style: Theme.of(context).textTheme.bodyLarge,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _ClientSearchSheet extends StatefulWidget {
  const _ClientSearchSheet({
    required this.clients,
    required this.selectedId,
    required this.showPhone,
    required this.title,
    required this.searchHint,
    required this.emptyLabel,
  });

  final List<ClientModel> clients;
  final String? selectedId;
  final bool showPhone;
  final String title;
  final String searchHint;
  final String emptyLabel;

  @override
  State<_ClientSearchSheet> createState() => _ClientSearchSheetState();
}

class _ClientSearchSheetState extends State<_ClientSearchSheet> {
  final _queryController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  List<ClientModel> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.clients;
    return widget.clients.where((c) {
      return c.name.toLowerCase().contains(q) ||
          c.phone.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final height = MediaQuery.sizeOf(context).height * 0.75;

    return SizedBox(
      height: height,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _queryController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: widget.searchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _queryController.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(child: Text(widget.emptyLabel))
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final client = filtered[index];
                      final selected = client.id == widget.selectedId;
                      return ListTile(
                        selected: selected,
                        title: Text(client.name),
                        subtitle: widget.showPhone ? Text(client.phone) : null,
                        trailing: selected
                            ? const Icon(Icons.check)
                            : null,
                        onTap: () => Navigator.pop(context, client),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
