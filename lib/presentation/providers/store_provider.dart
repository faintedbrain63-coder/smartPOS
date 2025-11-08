import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StoreProvider extends ChangeNotifier {
  static const String _storeNameKey = 'store_name';
  static const String _defaultStoreName = 'SmartPOS';
  
  String _storeName = _defaultStoreName;
  bool _isLoading = false;

  String get storeName => _storeName;
  bool get isLoading => _isLoading;

  StoreProvider() {
    _loadStoreName();
  }

  Future<void> _loadStoreName() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _storeName = prefs.getString(_storeNameKey) ?? _defaultStoreName;
    } catch (e) {
      _storeName = _defaultStoreName;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> updateStoreName(String newName) async {
    if (newName.trim().isEmpty) {
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storeNameKey, newName.trim());
      _storeName = newName.trim();
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> resetStoreName() async {
    await updateStoreName(_defaultStoreName);
  }
}