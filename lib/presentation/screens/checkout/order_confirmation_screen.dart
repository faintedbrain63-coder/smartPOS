import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/checkout_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/order_provider.dart';
import '../../../domain/entities/sale.dart';
import '../main_screen.dart';
import 'order_management_screen.dart';

class OrderConfirmationScreen extends StatefulWidget {
  final Sale sale;

  const OrderConfirmationScreen({
    super.key,
    required this.sale,
  });

  @override
  State<OrderConfirmationScreen> createState() => _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen> {
  @override
  void initState() {
    super.initState();
    
    // Refresh order provider to include the new sale
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      orderProvider.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Confirmation'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Consumer<CurrencyProvider>(
        builder: (context, currencyProvider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Success icon and message
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    size: 80,
                    color: Colors.green[600],
                  ),
                ),
                const SizedBox(height: 24),
                
                const Text(
                  'Payment Successful!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 8),
                
                Text(
                  'Order #${widget.sale.id}',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 32),
                
                // Transaction summary card
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Transaction Summary',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        _buildSummaryRow(
                          'Date & Time',
                          _formatDateTime(widget.sale.saleDate),
                        ),
                        
                        if (widget.sale.customerName != null)
                          _buildSummaryRow(
                            'Customer',
                            widget.sale.customerName!,
                          ),
                        
                        _buildSummaryRow(
                          'Payment Method',
                          _formatPaymentMethod(widget.sale.paymentMethod),
                        ),
                        
                        const Divider(height: 24),
                        
                        _buildSummaryRow(
                          'Subtotal',
                          currencyProvider.formatPrice(widget.sale.totalAmount),
                          isAmount: true,
                        ),
                        
                        _buildSummaryRow(
                          'Amount Paid',
                          currencyProvider.formatPrice(widget.sale.paymentAmount),
                          isAmount: true,
                        ),
                        
                        _buildSummaryRow(
                          'Change',
                          currencyProvider.formatPrice(widget.sale.changeAmount),
                          isAmount: true,
                          isChange: true,
                        ),
                        
                        const Divider(height: 24),
                        
                        _buildSummaryRow(
                          'Total',
                          currencyProvider.formatPrice(widget.sale.totalAmount),
                          isAmount: true,
                          isTotal: true,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Receipt information
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 48,
                          color: Colors.blue[600],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Receipt Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Transaction ID: ${widget.sale.id}',
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          'Status: ${widget.sale.transactionStatus.toUpperCase()}',
                          style: TextStyle(
                            color: Colors.green[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Action buttons
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _navigateToNewSale(),
                        icon: const Icon(Icons.add_shopping_cart),
                        label: const Text('New Sale'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _navigateToOrderHistory(),
                        icon: const Icon(Icons.history),
                        label: const Text('View Order History'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _navigateToHome(),
                        icon: const Icon(Icons.home),
                        label: const Text('Back to Home'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Additional information
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue[600],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Thank you for your purchase!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your transaction has been completed successfully.',
                        style: TextStyle(
                          color: Colors.blue[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isAmount = false,
    bool isTotal = false,
    bool isChange = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal 
                  ? Theme.of(context).textTheme.bodyLarge?.color 
                  : Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal || isAmount ? FontWeight.bold : FontWeight.normal,
              color: isTotal
                  ? Colors.blue[600]
                  : isChange
                      ? Colors.green[600]
                      : isAmount
                          ? Theme.of(context).textTheme.bodyLarge?.color
                          : Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatPaymentMethod(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'Cash';
      case 'card':
        return 'Card Payment';
      case 'mobile':
        return 'Mobile Payment';
      default:
        return method;
    }
  }

  void _navigateToNewSale() {
    // Clear both providers for a fresh start
    final checkoutProvider = Provider.of<CheckoutProvider>(context, listen: false);
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    checkoutProvider.clearCart();
    cartProvider.clearCart();
    
    // Navigate to main screen and then to sales tab (index 2)
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const MainScreen(initialIndex: 2), // Sales tab (index 2)
      ),
      (route) => false,
    );
  }

  void _navigateToOrderHistory() {
    // Clear both providers for a fresh start
    final checkoutProvider = Provider.of<CheckoutProvider>(context, listen: false);
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    checkoutProvider.clearCart();
    cartProvider.clearCart();
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const OrderManagementScreen(),
      ),
    );
  }

  void _navigateToHome() {
    // Clear both providers for a fresh start
    final checkoutProvider = Provider.of<CheckoutProvider>(context, listen: false);
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    checkoutProvider.clearCart();
    cartProvider.clearCart();
    
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const MainScreen(initialIndex: 0), // Dashboard tab
      ),
      (route) => false,
    );
  }
}