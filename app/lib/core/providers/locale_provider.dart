import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/storage_service.dart';

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier(ref.watch(storageServiceProvider));
});

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier(this._storage) : super(_loadInitial(_storage));

  final StorageService _storage;

  static Locale _loadInitial(StorageService storage) {
    final code = storage.getLocale();
    return Locale(code);
  }

  Future<void> setLocale(String languageCode) async {
    await _storage.setLocale(languageCode);
    state = Locale(languageCode);
  }
}
