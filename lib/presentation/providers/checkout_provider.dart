import 'package:flutter/foundation.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/sale_item.dart';
import '../../domain/repositories/sale_repository.dart';
import '../../domain/repositories/product_repository.dart';
import '../../core/services/admob_service.dart';

class CheckoutItem {
  final Product product;
  int quantity;
  
  CheckoutItem({
    required this.product,
    this.quantity = 1,
  });
  
  double get totalPrice => product.sellingPrice * quantity;
  
  CheckoutItem copyWith({
    Product? product,
    int? quantity,
  }) {
    return CheckoutItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }
}

class CheckoutProvider with ChangeNotifier {
  final SaleRepository _saleRepository;
  final ProductRepository _productRepository;

  CheckoutProvider(this._saleRepository, this._productRepository);

  final List<CheckoutItem> _items = [];
  double _paymentAmount = 0.0;
  String _paymentMethod = 'cash';
  String? _customerName;
  double _discountPercent = 0.0;
  double _taxPercent = 0.0;
  bool _isProcessing = false;
  String? _error;

  // Getters
  List<CheckoutItem> get items => _items;
  double get paymentAmount => _paymentAmount;
  String get paymentMethod => _paymentMethod;
  String? get customerName => _customerName;
  double get discountPercent => _discountPercent;
  double get taxPercent => _taxPercent;
  bool get isProcessing => _isProcessing;
  String? get error => _error;

  // Calculated values
  double get subtotal => _items.fold(0.0, (sum, item) => sum + item.totalPrice);
  double get discountAmount => (subtotal * (_discountPercent.clamp(0.0, 100.0) / 100)).toDouble();
  double get taxableBase => (subtotal - discountAmount);
  double get taxAmount => (taxableBase * (_taxPercent.clamp(0.0, 100.0) / 100)).toDouble();
  double get total => (taxableBase + taxAmount);
  double get changeAmount => _paymentAmount - total;
  bool get hasValidPayment => _paymentAmount >= total;
  bool get canCompleteCheckout => _items.isNotEmpty && hasValidPayment;
  int get totalItemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  // Cart management
  void addItem(Product product, {int quantity = 1}) {
    final existingIndex = _items.indexWhere((item) => item.product.id == product.id);
    
    if (existingIndex >= 0) {
      _items[existingIndex].quantity += quantity;
    } else {
      _items.add(CheckoutItem(product: product, quantity: quantity));
    }
    
    notifyListeners();
  }

  void removeItem(int productId) {
    _items.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  void updateItemQuantity(int productId, int quantity) {
    if (quantity <= 0) {
      removeItem(productId);
      return;
    }

    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      _items[index].quantity = quantity;
      notifyListeners();
    }
  }

  void incrementItemQuantity(int productId) {
    print('Incrementing quantity for product ID: $productId');
    final index = _items.indexWhere((item) => item.product.id == productId);
    print('Found item at index: $index');
    if (index >= 0) {
      print('Current quantity: ${_items[index].quantity}');
      _items[index].quantity++;
      print('New quantity: ${_items[index].quantity}');
      notifyListeners();
    } else {
      print('Product not found in cart');
    }
  }

  void decrementItemQuantity(int productId) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      if (_items[index].quantity > 1) {
        _items[index].quantity--;
      } else {
        removeItem(productId);
      }
      notifyListeners();
    }
  }

  void clearCart() {
    _items.clear();
    _paymentAmount = 0.0;
    _paymentMethod = 'cash'; // Reset to default payment method
    _customerName = null;
    _error = null;
    _isProcessing = false; // Reset processing state
    notifyListeners();
  }

  // Payment management
  void setPaymentAmount(double amount) {
    _paymentAmount = amount;
    notifyListeners();
  }

  void setPaymentMethod(String method) {
    _paymentMethod = method;
    notifyListeners();
  }

  void setDiscountPercent(double percent) {
    _discountPercent = percent.isNaN ? 0.0 : percent;
    notifyListeners();
  }

  void setTaxPercent(double percent) {
    _taxPercent = percent.isNaN ? 0.0 : percent;
    notifyListeners();
  }

  void setCustomerName(String? name) {
    _customerName = name;
    notifyListeners();
  }

  // Numeric keypad input
  void addDigitToPayment(String digit) {
    final currentString = _paymentAmount.toStringAsFixed(2).replaceAll('.', '');
    final newString = currentString + digit;
    
    if (newString.length <= 10) { // Limit to reasonable amount
      final newAmount = double.parse(newString) / 100;
      setPaymentAmount(newAmount);
    }
  }

  void removeLastDigitFromPayment() {
    final currentString = _paymentAmount.toStringAsFixed(2).replaceAll('.', '');
    
    if (currentString.length > 1) {
      final newString = currentString.substring(0, currentString.length - 1);
      final newAmount = double.parse(newString) / 100;
      setPaymentAmount(newAmount);
    } else {
      setPaymentAmount(0.0);
    }
  }

  void clearPaymentAmount() {
    setPaymentAmount(0.0);
  }

  void setExactAmount() {
    setPaymentAmount(subtotal);
  }

  // Quick amount buttons
  void addQuickAmount(double amount) {
    setPaymentAmount(_paymentAmount + amount);
  }

  // Checkout process
  Future<Sale?> completeCheckout() async {
    if (!canCompleteCheckout) {
      _setError('Cannot complete checkout: Invalid payment or empty cart');
      return null;
    }

    _setProcessing(true);
    _setError(null);

    try {
      // Create sale entity
      final sale = Sale(
        totalAmount: total,
        customerName: _customerName,
        saleDate: DateTime.now(),
        paymentAmount: _paymentAmount,
        changeAmount: changeAmount,
        paymentMethod: _paymentMethod,
        transactionStatus: 'completed',
      );

      // Insert the sale
      final saleId = await _saleRepository.insertSale(sale);
      if (saleId <= 0) {
        _setError('Failed to create sale');
        return null;
      }

      // Create and insert sale items
      final saleItems = _items.map((item) => SaleItem(
        saleId: saleId,
        productId: item.product.id!,
        quantity: item.quantity,
        unitPrice: item.product.sellingPrice,
        subtotal: item.totalPrice,
      )).toList();

      for (final item in saleItems) {
        await _saleRepository.insertSaleItem(item);
      }

      // Update product stock
      for (final item in _items) {
        if (item.product.id != null) {
          final updatedProduct = item.product.copyWith(
            stockQuantity: item.product.stockQuantity - item.quantity,
          );
          await _productRepository.updateProduct(updatedProduct);
        }
      }

      // Return the completed sale with ID
      final completedSale = sale.copyWith(id: saleId);
      
      // Clear the cart after successful checkout
      clearCart();
      
      // Show interstitial ad after successful transaction (with frequency control)
      // This respects user experience by not showing ads too frequently
      AdMobService().showAdAfterTransaction();
      
      return completedSale;
    } catch (e) {
      _setError('Failed to complete checkout: ${e.toString()}');
      return null;
    } finally {
      _setProcessing(false);
    }
  }

  // Validation methods
  bool validateStock() {
    for (final item in _items) {
      if (item.quantity > item.product.stockQuantity) {
        _setError('Insufficient stock for ${item.product.name}');
        return false;
      }
    }
    return true;
  }

  String? validateCheckout() {
    if (_items.isEmpty) {
      return 'Cart is empty';
    }
    
    if (!validateStock()) {
      return _error;
    }
    
    if (_paymentAmount < subtotal) {
      return 'Insufficient payment amount';
    }
    
    return null;
  }

  // Private helper methods
  void _setProcessing(bool processing) {
    _isProcessing = processing;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Load items from existing cart (for integration with existing cart provider)
  void loadFromCart(List<Map<String, dynamic>> cartItems) {
    _items.clear();
    
    for (final cartItem in cartItems) {
      if (cartItem['product'] is Product) {
        final product = cartItem['product'] as Product;
        final quantity = cartItem['quantity'] as int? ?? 1;
        
        _items.add(CheckoutItem(
          product: product,
          quantity: quantity,
        ));
      }
    }
    
    notifyListeners();
  }

  // Get checkout summary for confirmation
  Map<String, dynamic> getCheckoutSummary() {
    return {
      'items': _items.map((item) => {
        'product': item.product,
        'quantity': item.quantity,
        'totalPrice': item.totalPrice,
      }).toList(),
      'subtotal': subtotal,
      'paymentAmount': _paymentAmount,
      'changeAmount': changeAmount,
      'paymentMethod': _paymentMethod,
      'customerName': _customerName,
      'totalItemCount': totalItemCount,
    };
  }
}