import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/currency_provider.dart';

class CartSummaryWidget extends StatefulWidget {
  final ThemeData theme;
  final double subtotal;
  final double discountAmount;
  final double taxAmount;
  final double total;
  final double discount;
  final double tax;
  final bool isProcessing;
  final VoidCallback onClearCart;
  final Function(double, double, double) onCompleteSale;
  final Function(double) onDiscountChanged;
  final Function(double) onTaxChanged;

  const CartSummaryWidget({
    super.key,
    required this.theme,
    required this.subtotal,
    required this.discountAmount,
    required this.taxAmount,
    required this.total,
    required this.discount,
    required this.tax,
    required this.isProcessing,
    required this.onClearCart,
    required this.onCompleteSale,
    required this.onDiscountChanged,
    required this.onTaxChanged,
  });

  @override
  State<CartSummaryWidget> createState() => _CartSummaryWidgetState();
}

class _CartSummaryWidgetState extends State<CartSummaryWidget> {
  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
        color: widget.theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            border: Border(
              top: BorderSide(
        color: widget.theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Discount and Tax Controls - Ultra compact
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Discount (%)',
                          style: widget.theme.textTheme.labelSmall?.copyWith(fontSize: 9),
                        ),
                        const SizedBox(height: 1),
                        SizedBox(
                          height: 24,
                          child: TextFormField(
                            initialValue: widget.discount.toString(),
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 10),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              widget.onDiscountChanged(double.tryParse(value) ?? 0.0);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Tax (%)',
                          style: widget.theme.textTheme.labelSmall?.copyWith(fontSize: 9),
                        ),
                        const SizedBox(height: 1),
                        SizedBox(
                          height: 24,
                          child: TextFormField(
                            initialValue: widget.tax.toString(),
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 10),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              widget.onTaxChanged(double.tryParse(value) ?? 0.0);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 4),
              
              // Summary totals - Ultra compact
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Subtotal:',
                        style: widget.theme.textTheme.bodySmall?.copyWith(fontSize: 9),
                      ),
                      Consumer<CurrencyProvider>(
                        builder: (context, currencyProvider, child) {
                          return Text(
                            currencyProvider.formatPrice(widget.subtotal),
                            style: widget.theme.textTheme.bodySmall?.copyWith(fontSize: 9),
                          );
                        },
                      ),
                    ],
                  ),
                  if (widget.discount > 0) ...[
                    const SizedBox(height: 1),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Discount:',
                          style: widget.theme.textTheme.bodySmall?.copyWith(
                            color: widget.theme.colorScheme.error,
                            fontSize: 9,
                          ),
                        ),
                        Consumer<CurrencyProvider>(
                          builder: (context, currencyProvider, child) {
                            return Text(
                              '-${currencyProvider.formatPrice(widget.discountAmount)}',
                              style: widget.theme.textTheme.bodySmall?.copyWith(
                                color: widget.theme.colorScheme.error,
                                fontSize: 9,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                  if (widget.tax > 0) ...[
                    const SizedBox(height: 1),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tax:',
                          style: widget.theme.textTheme.bodySmall?.copyWith(fontSize: 9),
                        ),
                        Consumer<CurrencyProvider>(
                          builder: (context, currencyProvider, child) {
                            return Text(
                              currencyProvider.formatPrice(widget.taxAmount),
                              style: widget.theme.textTheme.bodySmall?.copyWith(fontSize: 9),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
        color: widget.theme.colorScheme.outline.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total:',
                          style: widget.theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        Consumer<CurrencyProvider>(
                          builder: (context, currencyProvider, child) {
                            return Text(
                              currencyProvider.formatPrice(widget.total),
                              style: widget.theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: widget.theme.colorScheme.primary,
                                fontSize: 11,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 4),
              
              // Checkout Button - Ultra compact
              SizedBox(
                width: double.infinity,
                height: 28,
                child: ElevatedButton.icon(
                  onPressed: widget.isProcessing ? null : () => widget.onCompleteSale(widget.total, widget.discountAmount, widget.taxAmount),
                  icon: widget.isProcessing
                      ? SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              widget.theme.colorScheme.onPrimary,
                            ),
                          ),
                        )
                      : const Icon(Icons.payment, size: 14),
                  label: Text(
                    widget.isProcessing ? 'Processing...' : 'Checkout',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}