import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/checkout_provider.dart';
import '../../providers/currency_provider.dart';
import '../../../domain/entities/product.dart';
import 'order_confirmation_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? initialCartItems;

  const CheckoutScreen({
    super.key,
    this.initialCartItems,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _amountPaidController = TextEditingController();

  @override
  void initState() {
    super.initState();
    
    // Load initial cart items if provided
    if (widget.initialCartItems != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final checkoutProvider = Provider.of<CheckoutProvider>(context, listen: false);
        checkoutProvider.loadFromCart(widget.initialCartItems!);
      });
    }
    
    // Initialize amount paid controller with current value
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final checkoutProvider = Provider.of<CheckoutProvider>(context, listen: false);
      _amountPaidController.text = checkoutProvider.paymentAmount.toStringAsFixed(2);
    });
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _amountPaidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer2<CheckoutProvider, CurrencyProvider>(
        builder: (context, checkoutProvider, currencyProvider, child) {
          if (checkoutProvider.items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No items in cart',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Order Summary Section with scrollable product list
              Expanded(
                child: _buildOrderSummary(checkoutProvider, currencyProvider),
              ),
              
              // Payment Section - Always visible
              _buildPaymentSection(checkoutProvider, currencyProvider),
              
              // Sticky Complete Payment Button
              _buildStickyPaymentButton(checkoutProvider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOrderSummary(CheckoutProvider checkoutProvider, CurrencyProvider currencyProvider) {
    return Container(
      padding: const EdgeInsets.all(12), // Reduced padding
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark 
            ? Colors.grey[800] 
            : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor, 
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with customer name input - Always visible
          Row(
            children: [
              Flexible(
                child: Text(
                  'Order Summary',
                  style: TextStyle(
                    fontSize: 14, // Reduced font size
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? Colors.grey[300] 
                        : Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 6), // Reduced spacing
              Flexible(
                child: SizedBox(
                  width: 140, // Reduced width
                  child: TextField(
                    controller: _customerNameController,
                    decoration: const InputDecoration(
                      labelText: 'Customer Name (Optional)',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6), // Reduced padding
                    ),
                    style: const TextStyle(fontSize: 12), // Reduced font size
                    onChanged: (value) {
                      checkoutProvider.setCustomerName(value.isEmpty ? null : value);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12), // Reduced spacing
          
          // Scrollable Items list with flexible height
          Expanded(
            child: ListView.builder(
              itemCount: checkoutProvider.items.length,
              itemBuilder: (context, index) {
                final item = checkoutProvider.items[index];
                return _buildOrderItem(item, checkoutProvider, currencyProvider);
              },
            ),
          ),
          
          const Divider(),
          
          // Totals - Always visible
          _buildTotalsSection(checkoutProvider, currencyProvider),
        ],
      ),
    );
  }

  Widget _buildOrderItem(CheckoutItem item, CheckoutProvider checkoutProvider, CurrencyProvider currencyProvider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      height: 50, // Fixed height to ensure consistent spacing
      child: Row(
        children: [
          // Product info - Increased flex for more space
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12, // Smaller font
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  currencyProvider.formatPrice(item.product.sellingPrice),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 10, // Smaller font
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 4), // Minimal spacing
          
          // Quantity controls - Compact design
          Container(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    checkoutProvider.decrementItemQuantity(item.product.id!);
                  },
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.remove, size: 12, color: Colors.red),
                  ),
                ),
                Container(
                  width: 30,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    item.quantity.toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    checkoutProvider.incrementItemQuantity(item.product.id!);
                  },
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add, size: 12, color: Colors.green),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 4), // Minimal spacing
          
          // Total price and remove button - Reduced flex
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    currencyProvider.formatPrice(item.quantity * item.product.sellingPrice),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    checkoutProvider.removeItem(item.product.id!);
                  },
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_outline, size: 12, color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsSection(CheckoutProvider checkoutProvider, CurrencyProvider currencyProvider) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Items (${checkoutProvider.totalItemCount})',
              style: TextStyle(
                fontSize: 12, // Reduced font size
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.grey[300] 
                    : Colors.black,
              ),
            ),
            Text(
              currencyProvider.formatPrice(checkoutProvider.subtotal),
              style: TextStyle(
                fontSize: 12, // Reduced font size
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.grey[300] 
                    : Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6), // Reduced spacing
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total',
              style: TextStyle(
                fontSize: 16, // Reduced font size
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.grey[300] 
                    : Colors.black,
              ),
            ),
            Text(
              currencyProvider.formatPrice(checkoutProvider.subtotal),
              style: const TextStyle(
                fontSize: 16, // Reduced font size
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentSection(CheckoutProvider checkoutProvider, CurrencyProvider currencyProvider) {
    return Container(
      padding: const EdgeInsets.all(8), // Further reduced padding
      color: Theme.of(context).brightness == Brightness.dark 
          ? Colors.grey[800] 
          : Colors.grey[50],
      child: Column(
        children: [
          // Payment input only (removed numeric keypad)
          _buildPaymentInput(checkoutProvider, currencyProvider),
        ],
      ),
    );
  }

  Widget _buildStickyPaymentButton(CheckoutProvider checkoutProvider) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark 
            ? Colors.grey[900] 
            : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 45,
          child: ElevatedButton(
            onPressed: checkoutProvider.canCompleteCheckout && !checkoutProvider.isProcessing
                ? () => _completeCheckout(checkoutProvider)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: checkoutProvider.isProcessing
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('Processing...', style: TextStyle(fontSize: 14)),
                    ],
                  )
                : const Text('Complete Payment'),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentInput(CheckoutProvider checkoutProvider, CurrencyProvider currencyProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment',
          style: TextStyle(
            fontSize: 14, // Reduced font size
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
        const SizedBox(height: 8), // Reduced spacing
        
        // Payment method selector
        Row(
          children: [
            Text(
              'Method: ',
              style: TextStyle(
                fontSize: 12, // Reduced font size
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            DropdownButton<String>(
              value: checkoutProvider.paymentMethod,
              dropdownColor: Theme.of(context).cardColor,
              style: TextStyle(
                fontSize: 12, // Reduced font size
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              items: [
                DropdownMenuItem(
                  value: 'cash', 
                  child: Text(
                    'Cash',
                    style: TextStyle(
                      fontSize: 12, // Reduced font size
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 'card', 
                  child: Text(
                    'Card',
                    style: TextStyle(
                      fontSize: 12, // Reduced font size
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 'mobile', 
                  child: Text(
                    'Mobile Payment',
                    style: TextStyle(
                      fontSize: 12, // Reduced font size
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  checkoutProvider.setPaymentMethod(value);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 8), // Reduced spacing
        
        // Payment amount input field
        SizedBox(
          height: 45, // Reduced height
          child: TextField(
            controller: _amountPaidController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(
              fontSize: 16, // Reduced font size
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
            decoration: InputDecoration(
              labelText: 'Amount Paid',
              labelStyle: TextStyle(
                fontSize: 11, // Reduced font size
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6), // Reduced border radius
              ),
              contentPadding: const EdgeInsets.all(8), // Reduced padding
              filled: true,
              fillColor: Theme.of(context).cardColor,
            ),
            onChanged: (value) {
               // Parse and validate input
               if (value.isEmpty) {
                 checkoutProvider.setPaymentAmount(0.0);
                 return;
               }
               
               // Allow decimal input with proper validation
               final cleanValue = value.replaceAll(RegExp(r'[^0-9.]'), '');
               final parts = cleanValue.split('.');
               
               // Ensure only one decimal point and max 2 decimal places
               if (parts.length <= 2) {
                 String validValue = parts[0];
                 if (parts.length == 2) {
                   final decimalPart = parts[1].length > 2 ? parts[1].substring(0, 2) : parts[1];
                   validValue = '$validValue.$decimalPart';
                 }
                 
                 final amount = double.tryParse(validValue);
                 if (amount != null && amount >= 0) {
                   checkoutProvider.setPaymentAmount(amount);
                   
                   // Update controller text if it was cleaned
                   if (validValue != value) {
                     _amountPaidController.text = validValue;
                     _amountPaidController.selection = TextSelection.fromPosition(
                       TextPosition(offset: validValue.length),
                     );
                   }
                 }
               }
             },
          ),
        ),
        const SizedBox(height: 8), // Reduced spacing
        
        // Change amount
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8), // Reduced padding
          decoration: BoxDecoration(
            border: Border.all(
              color: checkoutProvider.changeAmount >= 0 ? Colors.green : Colors.red,
            ),
            borderRadius: BorderRadius.circular(6), // Reduced border radius
            color: checkoutProvider.changeAmount >= 0 
                ? (Theme.of(context).brightness == Brightness.dark 
                    ? Colors.green[900]?.withOpacity(0.3) 
                    : Colors.green[50])
                : (Theme.of(context).brightness == Brightness.dark 
                    ? Colors.red[900]?.withOpacity(0.3) 
                    : Colors.red[50]),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                checkoutProvider.changeAmount >= 0 ? 'Change' : 'Insufficient Payment',
                style: TextStyle(
                  color: checkoutProvider.changeAmount >= 0 ? Colors.green[700] : Colors.red[700],
                  fontSize: 10, // Reduced font size
                ),
              ),
              Text(
                currencyProvider.formatPrice(checkoutProvider.changeAmount.abs()),
                style: TextStyle(
                  fontSize: 14, // Reduced font size
                  fontWeight: FontWeight.bold,
                  color: checkoutProvider.changeAmount >= 0 ? Colors.green[700] : Colors.red[700],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8), // Reduced spacing
        
        // Quick amount buttons
        Wrap(
          spacing: 3, // Reduced spacing
          runSpacing: 3,
          children: [
            ElevatedButton(
              onPressed: () => checkoutProvider.setExactAmount(),
              child: const Text('Exact', style: TextStyle(fontSize: 10)), // Reduced font size
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.grey[700] 
                    : Colors.blue[100],
                foregroundColor: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white 
                    : Colors.blue[800],
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), // Reduced padding
                minimumSize: const Size(40, 25), // Reduced size
              ),
            ),
            ElevatedButton(
              onPressed: () => checkoutProvider.addQuickAmount(5),
              child: const Text('+5', style: TextStyle(fontSize: 10)), // Reduced font size
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.grey[700] 
                    : Colors.blue[100],
                foregroundColor: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white 
                    : Colors.blue[800],
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), // Reduced padding
                minimumSize: const Size(40, 25), // Reduced size
              ),
            ),
            ElevatedButton(
              onPressed: () => checkoutProvider.addQuickAmount(10),
              child: const Text('+10', style: TextStyle(fontSize: 10)), // Reduced font size
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.grey[700] 
                    : Colors.blue[100],
                foregroundColor: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white 
                    : Colors.blue[800],
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), // Reduced padding
                minimumSize: const Size(40, 25), // Reduced size
              ),
            ),
            ElevatedButton(
              onPressed: () => checkoutProvider.addQuickAmount(20),
              child: const Text('+20', style: TextStyle(fontSize: 10)), // Reduced font size
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.grey[700] 
                    : Colors.blue[100],
                foregroundColor: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white 
                    : Colors.blue[800],
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), // Reduced padding
                minimumSize: const Size(40, 25), // Reduced size
              ),
            ),
          ],
        ),
      ],
    );
  }



  Future<void> _completeCheckout(CheckoutProvider checkoutProvider) async {
    // Validate checkout
    final validationError = checkoutProvider.validateCheckout();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Complete the checkout
    final sale = await checkoutProvider.completeCheckout();
    
    if (sale != null) {
      // Navigate to order confirmation screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => OrderConfirmationScreen(sale: sale),
          ),
        );
      }
    } else {
      // Show error message
      if (mounted && checkoutProvider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(checkoutProvider.error!),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}