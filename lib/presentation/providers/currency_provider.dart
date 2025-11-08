import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Currency {
  final String code;
  final String name;
  final String symbol;

  const Currency({
    required this.code,
    required this.name,
    required this.symbol,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Currency &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;
}

class CurrencyProvider extends ChangeNotifier {
  static const String _currencyCodeKey = 'selected_currency_code';
  static const String _defaultCurrencyCode = 'USD';

  static const List<Currency> _availableCurrencies = [
    Currency(code: 'PHP', name: 'Philippine Peso', symbol: '₱'),
    Currency(code: 'USD', name: 'US Dollar', symbol: '\$'),
    Currency(code: 'EUR', name: 'Euro', symbol: '€'),
    Currency(code: 'GBP', name: 'British Pound', symbol: '£'),
    Currency(code: 'JPY', name: 'Japanese Yen', symbol: '¥'),
    Currency(code: 'CAD', name: 'Canadian Dollar', symbol: 'C\$'),
    Currency(code: 'AUD', name: 'Australian Dollar', symbol: 'A\$'),
    Currency(code: 'CHF', name: 'Swiss Franc', symbol: 'CHF'),
    Currency(code: 'CNY', name: 'Chinese Yuan', symbol: '¥'),
    Currency(code: 'INR', name: 'Indian Rupee', symbol: '₹'),
  ];

  Currency _selectedCurrency = _availableCurrencies.firstWhere(
    (currency) => currency.code == _defaultCurrencyCode,
  );
  bool _isLoading = false;

  Currency get selectedCurrency => _selectedCurrency;
  List<Currency> get availableCurrencies => _availableCurrencies;
  bool get isLoading => _isLoading;

  CurrencyProvider() {
    _loadSelectedCurrency();
  }

  Future<void> _loadSelectedCurrency() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_currencyCodeKey) ?? _defaultCurrencyCode;
      
      _selectedCurrency = _availableCurrencies.firstWhere(
        (currency) => currency.code == savedCode,
        orElse: () => _availableCurrencies.firstWhere(
          (currency) => currency.code == _defaultCurrencyCode,
        ),
      );
    } catch (e) {
      _selectedCurrency = _availableCurrencies.firstWhere(
        (currency) => currency.code == _defaultCurrencyCode,
      );
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> updateCurrency(Currency currency) async {
    if (currency == _selectedCurrency) {
      return true;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currencyCodeKey, currency.code);
      _selectedCurrency = currency;
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  String formatPrice(double price) {
    // Format price with currency symbol
    final formattedPrice = price.toStringAsFixed(2);
    
    // Handle special formatting for different currencies
    switch (_selectedCurrency.code) {
      case 'JPY':
      case 'CNY':
        // No decimal places for these currencies
        return '${_selectedCurrency.symbol}${price.toStringAsFixed(0)}';
      case 'EUR':
        // Euro typically goes after the amount in some countries
        return '$formattedPrice${_selectedCurrency.symbol}';
      default:
        return '${_selectedCurrency.symbol}$formattedPrice';
    }
  }

  String formatPriceWithoutSymbol(double price) {
    switch (_selectedCurrency.code) {
      case 'JPY':
      case 'CNY':
        return price.toStringAsFixed(0);
      default:
        return price.toStringAsFixed(2);
    }
  }

  Future<void> resetToDefault() async {
    final defaultCurrency = _availableCurrencies.firstWhere(
      (currency) => currency.code == _defaultCurrencyCode,
    );
    await updateCurrency(defaultCurrency);
  }
}