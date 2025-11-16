import 'package:flutter/foundation.dart';
import '../../domain/entities/customer.dart';
import '../../domain/repositories/customer_repository.dart';

class CustomerProvider with ChangeNotifier {
  final CustomerRepository _repository;

  CustomerProvider(this._repository);

  List<Customer> _customers = [];
  bool _isLoading = false;
  String? _error;

  List<Customer> get customers => _customers;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadCustomers() async {
    _setLoading(true);
    _setError(null);
    try {
      _customers = await _repository.getAllCustomers();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<int> addCustomer(Customer customer) async {
    try {
      final id = await _repository.insertCustomer(customer);
      await loadCustomers();
      return id;
    } catch (e) {
      _setError(e.toString());
      return -1;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }
}
