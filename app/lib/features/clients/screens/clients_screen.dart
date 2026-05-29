import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../models/client_model.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/loading_widget.dart';

class ClientsScreen extends ConsumerWidget {
  const ClientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsAsync = ref.watch(clientsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => _showClientDialog(context, ref),
          ),
        ],
      ),
      body: clientsAsync.when(
        loading: () => const LoadingShimmer(),
        error: (e, _) => ErrorStateWidget(message: e.toString(), onRetry: () => ref.invalidate(clientsProvider)),
        data: (clients) {
          if (clients.isEmpty) {
            return const EmptyStateWidget(icon: Icons.people, title: 'No clients yet');
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
                    subtitle: Text('${client.phone}\n${client.address}'),
                    isThreeLine: true,
                    trailing: Text(context.formatCurrency(client.balance)),
                    onTap: () => _showClientDialog(context, ref, client: client),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showClientDialog(BuildContext context, WidgetRef ref, {ClientModel? client}) {
    final nameController = TextEditingController(text: client?.name ?? '');
    final phoneController = TextEditingController(text: client?.phone ?? '');
    final addressController = TextEditingController(text: client?.address ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(client == null ? 'Add Client' : 'Edit Client'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone')),
            TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Address')),
          ],
        ),
        actions: [
          if (client != null)
            TextButton(
              onPressed: () async {
                await ref.read(clientRepositoryProvider).deleteClient(client.id);
                ref.invalidate(clientsProvider);
                if (context.mounted) Navigator.pop(ctx);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (client == null) {
                await ref.read(clientRepositoryProvider).createClient(ClientModel(
                      id: '',
                      name: nameController.text,
                      phone: phoneController.text,
                      address: addressController.text,
                    ));
              } else {
                await ref.read(clientRepositoryProvider).updateClient(client.id, {
                  'name': nameController.text,
                  'phone': phoneController.text,
                  'address': addressController.text,
                });
              }
              ref.invalidate(clientsProvider);
              if (context.mounted) Navigator.pop(ctx);
            },
            child: Text(client == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }
}
