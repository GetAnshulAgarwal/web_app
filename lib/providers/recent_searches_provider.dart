import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class RecentSearchesProvider extends ChangeNotifier {
  static const String boxName = 'recent_searches';
  List<String> _recentSearches = [];

  List<String> get recentSearches => _recentSearches;

  RecentSearchesProvider() {
    _loadSearches();
  }

  Future<void> _loadSearches() async {
    var box = await Hive.openBox<String>(boxName);
    _recentSearches = box.values.toList().reversed.toList();
    notifyListeners();
  }

  Future<void> addSearch(String query) async {
    if (query.trim().isEmpty) return;
    var box = await Hive.openBox<String>(boxName);
    // Remove if already exists, then add to top
    _recentSearches.remove(query);
    _recentSearches.insert(0, query);
    await box.clear();
    await box.addAll(_recentSearches);
    notifyListeners();
  }

  Future<void> clearSearches() async {
    var box = await Hive.openBox<String>(boxName);
    await box.clear();
    _recentSearches.clear();
    notifyListeners();
  }
}
