import '../core/constants/api_constants.dart';
import '../models/client_model.dart';
import '../models/account_statement_model.dart';
import '../models/invoice_model.dart';
import '../models/treasury_entry_item.dart';
import '../services/api_client.dart';
import '../services/cache_service.dart';

class ClientRepository {
  ClientRepository(this._api, this._cache);

  final ApiClient _api;
  final CacheService _cache;

  /// Loads every client page so the list is not capped at 50.
  Future<List<ClientModel>> getClients({String? search}) async {
    final hasSearch = search != null && search.isNotEmpty;

    // Prefer local cache when offline so the full client list stays available.
    if (!await _cache.isOnline) {
      final local = _clientsFromCache();
      if (local != null) {
        return _filterClients(local, search);
      }
    }

    try {
      const limit = 100;
      var page = 1;
      var totalPages = 1;
      final all = <ClientModel>[];

      do {
        final response = await _api.get(
          ApiConstants.clients,
          queryParameters: {
            if (hasSearch) 'search': search,
            'page': page,
            'limit': limit,
          },
        );
        final data = response.data as Map<String, dynamic>;
        final list = (data['data'] as List)
            .map((e) => ClientModel.fromJson(e as Map<String, dynamic>))
            .toList();
        all.addAll(list);

        final pagination = data['pagination'] as Map<String, dynamic>?;
        totalPages = (pagination?['pages'] as num?)?.toInt() ?? 1;
        page++;
      } while (page <= totalPages);

      // Never overwrite the full offline list with a search partial.
      if (!hasSearch) {
        await _cache.cacheData('clients', {
          'items': all.map((c) => c.toJson()).toList(),
        });
      }
      return all;
    } catch (e) {
      if (await _cache.shouldQueueError(e) || !await _cache.isOnline) {
        final local = _clientsFromCache();
        if (local != null) {
          return _filterClients(local, search);
        }
      }
      rethrow;
    }
  }

  List<ClientModel>? _clientsFromCache() {
    final cached = _cache.getCached('clients');
    if (cached == null) return null;
    return (cached['items'] as List)
        .map((e) => ClientModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  List<ClientModel> _filterClients(List<ClientModel> clients, String? search) {
    if (search == null || search.isEmpty) return clients;
    final q = search.trim().toLowerCase();
    return clients
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.phone.toLowerCase().contains(q) ||
              c.address.toLowerCase().contains(q) ||
              c.email.toLowerCase().contains(q),
        )
        .toList();
  }

  Future<ClientModel> createClient(ClientModel client, {String? password}) async {
    final response = await _api.post(
      ApiConstants.clients,
      data: client.toJson(password: password),
    );
    final data = response.data as Map<String, dynamic>;
    return ClientModel.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<ClientModel> updateClient(String id, Map<String, dynamic> updates) async {
    final response = await _api.put('${ApiConstants.clients}/$id', data: updates);
    final data = response.data as Map<String, dynamic>;
    return ClientModel.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<void> deleteClient(String id) async {
    await _api.delete('${ApiConstants.clients}/$id');
  }

  Future<AccountStatement> getAccountStatement(String id) async {
    if (!await _cache.isOnline) {
      return _statementOffline(id);
    }

    try {
      final response = await _api.get('${ApiConstants.clients}/$id/statement');
      final data = response.data as Map<String, dynamic>;
      final statement =
          AccountStatement.fromJson(data['data'] as Map<String, dynamic>);
      await _cache.cacheData('client_statement_$id', statement.toJson());
      return statement;
    } catch (e) {
      if (await _cache.shouldQueueError(e) || !await _cache.isOnline) {
        return _statementOffline(id);
      }
      rethrow;
    }
  }

  AccountStatement _statementOffline(String id) {
    final cached = _cache.getCached('client_statement_$id');
    if (cached != null) {
      return AccountStatement.fromJson(cached);
    }
    final built = _buildStatementFromLocalWork(id);
    if (built != null) return built;
    throw StateError('Client statement unavailable offline');
  }

  /// Builds a client statement from cached invoices + collections (+ pending).
  AccountStatement? _buildStatementFromLocalWork(String clientId) {
    final clients = _clientsFromCache() ?? const <ClientModel>[];
    ClientModel? client;
    for (final c in clients) {
      if (c.id == clientId) {
        client = c;
        break;
      }
    }

    final invoices = _invoicesForClient(clientId);
    final collections = _collectionsForClient(clientId);

    if (client == null && invoices.isEmpty && collections.isEmpty) {
      return null;
    }

    client ??= ClientModel(
      id: clientId,
      name: invoices.isNotEmpty
          ? (invoices.first.clientName ?? 'عميل')
          : (collections.first.clientName ?? 'عميل'),
      phone: invoices.isNotEmpty
          ? (invoices.first.clientPhone ?? '')
          : (collections.first.clientPhone ?? ''),
      balance: 0,
    );

    final entries = <AccountStatementEntry>[];

    for (final invoice in invoices) {
      final affectsBalance = invoice.paymentStatus != 'paid';
      entries.add(
        AccountStatementEntry(
          id: invoice.id,
          type: 'distribution',
          date: invoice.createdAt ?? DateTime.now(),
          description: 'فاتورة توزيع #${invoice.invoiceNumber}',
          subtitle: invoice.employeeName ?? '',
          debit: affectsBalance ? invoice.totalPrice : 0,
          credit: 0,
          balanceAfter: invoice.balanceAfter,
          reference: invoice.invoiceNumber,
        ),
      );
    }

    for (final collection in collections) {
      final amountPaid = collection.amountPaid ?? 0;
      final amountDeducted = collection.amountDeducted ?? 0;
      entries.add(
        AccountStatementEntry(
          id: collection.id,
          type: 'collection',
          date: collection.collectionDate ??
              collection.createdAt ??
              DateTime.now(),
          description: 'فاتورة تحصيل',
          subtitle: collection.employeeName ?? '',
          debit: 0,
          credit: amountPaid + amountDeducted,
          amountPaid: amountPaid,
          amountDeducted: amountDeducted,
          balanceAfter: collection.balanceAfter,
        ),
      );
    }

    entries.sort((a, b) => a.date.compareTo(b.date));

    final movementNet = entries.fold<double>(
      0,
      (sum, e) => sum + e.debit - e.credit,
    );
    final currentBalance = client.balance < 0 ? 0.0 : client.balance;
    final openingBalance =
        (currentBalance - movementNet) < 0 ? 0.0 : (currentBalance - movementNet);

    if (openingBalance > 0.001) {
      entries.insert(
        0,
        AccountStatementEntry(
          id: '$clientId-prior-debt',
          type: 'distribution',
          date: entries.isNotEmpty ? entries.first.date : DateTime.now(),
          description: 'مديونية سابقة',
          subtitle: '',
          debit: openingBalance,
          credit: 0,
        ),
      );
    }

    var running = 0.0;
    final withBalances = <AccountStatementEntry>[];
    for (final entry in entries) {
      running += entry.debit - entry.credit;
      final bal = running < 0 ? 0.0 : running;
      withBalances.add(
        AccountStatementEntry(
          id: entry.id,
          type: entry.type,
          date: entry.date,
          description: entry.description,
          subtitle: entry.subtitle,
          debit: entry.debit,
          credit: entry.credit,
          balanceAfter: bal,
          reference: entry.reference,
          amountPaid: entry.amountPaid,
          amountDeducted: entry.amountDeducted,
        ),
      );
    }

    return AccountStatement(
      entity: AccountStatementEntity(
        id: client.id,
        name: client.name,
        phone: client.phone,
        balance: client.balance,
      ),
      entries: withBalances.reversed.toList(),
    );
  }

  List<InvoiceModel> _invoicesForClient(String clientId) {
    final byId = <String, InvoiceModel>{};

    final cached = _cache.getCached('invoices');
    final items = cached?['items'];
    if (items is List) {
      for (final raw in items) {
        if (raw is! Map) continue;
        final inv = InvoiceModel.fromJson(Map<String, dynamic>.from(raw));
        if (inv.clientId == clientId) byId[inv.id] = inv;
      }
    }

    for (final item in _cache.getPendingSyncs(action: 'create_invoice')) {
      final id = item['id']?.toString() ?? '';
      final payload = Map<String, dynamic>.from(item['payload'] as Map? ?? {});
      if (payload['clientId']?.toString() != clientId) continue;
      final itemsRaw = payload['items'];
      final invItems = itemsRaw is List
          ? itemsRaw
              .whereType<Map>()
              .map((e) => InvoiceItemModel.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : <InvoiceItemModel>[];
      var totalWeight = 0.0;
      var totalPrice = 0.0;
      for (final line in invItems) {
        totalWeight += line.weight;
        totalPrice += line.weight * line.unitPrice;
      }
      byId['pending-$id'] = InvoiceModel(
        id: 'pending-$id',
        invoiceNumber: 'معلّق — مزامنة',
        clientId: clientId,
        employeeId: payload['employeeId']?.toString() ?? '',
        items: invItems,
        totalWeight: totalWeight,
        totalPrice: totalPrice,
        paymentStatus: 'pending',
        createdAt: DateTime.tryParse(item['timestamp']?.toString() ?? '') ??
            DateTime.now(),
      );
    }

    final list = byId.values.toList()
      ..sort((a, b) => (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));
    return list;
  }

  List<TreasuryEntryItem> _collectionsForClient(String clientId) {
    final byId = <String, TreasuryEntryItem>{};

    final cached = _cache.getCached('collections');
    final items = cached?['items'];
    if (items is List) {
      for (final raw in items) {
        if (raw is! Map) continue;
        final entry = TreasuryEntryItem.fromJson(Map<String, dynamic>.from(raw));
        if (entry.clientId == clientId) byId[entry.id] = entry;
      }
    }

    for (final item in _cache.getPendingSyncs(action: 'create_collection')) {
      final id = item['id']?.toString() ?? '';
      final payload = Map<String, dynamic>.from(item['payload'] as Map? ?? {});
      if (payload['clientId']?.toString() != clientId) continue;
      final amountPaid = (payload['amountPaid'] as num?)?.toDouble() ?? 0;
      byId['pending-$id'] = TreasuryEntryItem(
        id: 'pending-$id',
        category: 'collection',
        amount: amountPaid,
        description: 'معلّق — مزامنة',
        clientId: clientId,
        employeeId: payload['employeeId']?.toString(),
        collectionDate:
            DateTime.tryParse(payload['collectionDate']?.toString() ?? ''),
        amountPaid: amountPaid,
        amountDeducted: (payload['amountDeducted'] as num?)?.toDouble(),
        createdAt: DateTime.tryParse(item['timestamp']?.toString() ?? '') ??
            DateTime.now(),
      );
    }

    final list = byId.values.toList()
      ..sort(
        (a, b) => (a.collectionDate ?? a.createdAt ?? DateTime(0))
            .compareTo(b.collectionDate ?? b.createdAt ?? DateTime(0)),
      );
    return list;
  }
}
