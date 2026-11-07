import 'package:flutter/material.dart';

import '../core/token_storage.dart';

class ThemeState extends ChangeNotifier {
  final TokenStorage storage;
  ThemeMode mode = ThemeMode.system;

  ThemeState(this.storage);

  Future<void> load() async {
    final saved = await storage.readTheme();
    mode = switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    notifyListeners();
  }

  Future<void> set(ThemeMode next) async {
    mode = next;
    notifyListeners();
    await storage.writeTheme(next.name);
  }
}
