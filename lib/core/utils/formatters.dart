import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

class Formatters {
  // Currency formatter - deprecated, use CurrencyProvider.formatPrice instead
  static String formatCurrency(double amount) {
    return '${AppConstants.currencySymbol}${amount.toStringAsFixed(2)}';
  }

  // Date formatters
  static String formatDate(DateTime date) {
    return DateFormat(AppConstants.displayDateFormat).format(date);
  }

  static String formatDateTime(DateTime dateTime) {
    return DateFormat(AppConstants.displayDateTimeFormat).format(dateTime);
  }

  static String formatDateForDatabase(DateTime date) {
    return DateFormat(AppConstants.dateFormat).format(date);
  }

  static String formatDateTimeForDatabase(DateTime dateTime) {
    return DateFormat(AppConstants.dateTimeFormat).format(dateTime);
  }

  // Number formatters
  static String formatNumber(num number) {
    return NumberFormat('#,##0').format(number);
  }

  static String formatDecimal(double number, {int decimalPlaces = 2}) {
    return number.toStringAsFixed(decimalPlaces);
  }

  static String formatPercentage(double percentage) {
    return '${percentage.toStringAsFixed(1)}%';
  }

  // Stock status formatters
  static String formatStockStatus(int quantity) {
    if (quantity <= 0) {
      return 'Out of Stock';
    } else if (quantity <= AppConstants.criticalStockThreshold) {
      return 'Critical Stock';
    } else if (quantity <= AppConstants.lowStockThreshold) {
      return 'Low Stock';
    } else {
      return 'In Stock';
    }
  }

  // Barcode formatter
  static String formatBarcode(String barcode) {
    if (barcode.length >= 12) {
      // Format as UPC/EAN barcode with spaces
      return barcode.replaceAllMapped(
        RegExp(r'(\d{1})(\d{5})(\d{5})(\d{1})'),
        (match) => '${match[1]} ${match[2]} ${match[3]} ${match[4]}',
      );
    }
    return barcode;
  }

  // Time ago formatter
  static String formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  // File size formatter
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
}