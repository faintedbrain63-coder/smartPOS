import 'package:telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;

class SalesReportData {
  final double todaySalesRevenue;
  final double todayProfit;
  final double monthSalesRevenue;
  final double monthProfit;
  final String currencySymbol;

  SalesReportData({
    required this.todaySalesRevenue,
    required this.todayProfit,
    required this.monthSalesRevenue,
    required this.monthProfit,
    required this.currencySymbol,
  });
}

abstract class SmsService {
  Future<bool> hasPermission();
  Future<bool> requestPermission();
  Future<bool> sendSms(String phoneNumber, String message);
  Future<bool> sendSmsToMultiple(List<String> phoneNumbers, String message);
  String generateSalesReportMessage(SalesReportData data);
}

class SmsServiceImpl implements SmsService {
  final Telephony _telephony = Telephony.instance;

  @override
  Future<bool> hasPermission() async {
    print('🔐 Checking SMS permission for platform: ${Platform.operatingSystem}');
    
    // For macOS/desktop platforms, we'll simulate permission as granted
    // since SMS functionality is typically not available on desktop
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      print('🔐 Desktop platform detected - simulating SMS permission as granted');
      return true;
    }
    
    try {
      final status = await Permission.sms.status;
      print('🔐 SMS permission status: $status');
      return status.isGranted;
    } catch (e) {
      print('🔐 Error checking SMS permission: $e');
      // Fallback to true for desktop platforms
      return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
    }
  }

  @override
  Future<bool> requestPermission() async {
    print('🔐 Requesting SMS permission for platform: ${Platform.operatingSystem}');
    
    // For macOS/desktop platforms, we'll simulate permission as granted
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      print('🔐 Desktop platform detected - simulating SMS permission request as granted');
      return true;
    }
    
    try {
      final status = await Permission.sms.request();
      print('🔐 SMS permission request result: $status');
      return status.isGranted;
    } catch (e) {
      print('🔐 Error requesting SMS permission: $e');
      // Fallback to true for desktop platforms
      return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
    }
  }

  @override
  Future<bool> sendSms(String phoneNumber, String message) async {
    print('📱 Attempting to send SMS to: $phoneNumber');
    print('📱 Platform: ${Platform.operatingSystem}');
    print('📱 Message length: ${message.length}');
    
    // For macOS/desktop platforms, we'll simulate SMS sending
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      print('📱 Desktop platform detected - simulating SMS send');
      print('📱 SIMULATED SMS TO: $phoneNumber');
      print('📱 SIMULATED MESSAGE:');
      print('--- MESSAGE START ---');
      print(message);
      print('--- MESSAGE END ---');
      
      // Simulate a small delay
      await Future.delayed(const Duration(milliseconds: 500));
      print('📱 Simulated SMS sent successfully');
      return true;
    }
    
    try {
      // Check if we have SMS permission
      if (!await hasPermission()) {
        print('📱 SMS permission not granted');
        return false;
      }

      await _telephony.sendSms(
        to: phoneNumber,
        message: message,
      );
      
      print('📱 SMS sent successfully to $phoneNumber');
      return true;
    } catch (e) {
      print('📱 Error sending SMS to $phoneNumber: $e');
      return false;
    }
  }

  @override
  Future<bool> sendSmsToMultiple(List<String> phoneNumbers, String message) async {
    print('📱 Sending SMS to ${phoneNumbers.length} recipients');
    print('📱 Platform: ${Platform.operatingSystem}');
    
    bool allSuccessful = true;
    
    for (int i = 0; i < phoneNumbers.length; i++) {
      final phoneNumber = phoneNumbers[i];
      print('📱 Sending to recipient ${i + 1}/${phoneNumbers.length}: $phoneNumber');
      
      final success = await sendSms(phoneNumber, message);
      if (!success) {
        print('📱 Failed to send SMS to $phoneNumber');
        allSuccessful = false;
      }
      
      // Add delay between messages to avoid rate limiting
      if (i < phoneNumbers.length - 1) {
        print('📱 Waiting 1 second before next SMS...');
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    
    print('📱 Bulk SMS sending complete. All successful: $allSuccessful');
    return allSuccessful;
  }

  @override
  String generateSalesReportMessage(SalesReportData data) {
    print('📝 Generating sales report message...');
    print('📝 Input data:');
    print('   📝 Today Sales Revenue: ${data.todaySalesRevenue}');
    print('   📝 Today Profit: ${data.todayProfit}');
    print('   📝 Month Sales Revenue: ${data.monthSalesRevenue}');
    print('   📝 Month Profit: ${data.monthProfit}');
    print('   📝 Currency Symbol: "${data.currencySymbol}"');
    
    final currency = data.currencySymbol;
    
    final message = '''📊 Sales Summary Report
----------------------------
Sales Revenue Today: $currency${_formatCurrency(data.todaySalesRevenue)}
Profit Today: $currency${_formatCurrency(data.todayProfit)}
Current Month Sales Revenue: $currency${_formatCurrency(data.monthSalesRevenue)}
Current Month Sales Profit: $currency${_formatCurrency(data.monthProfit)}
----------------------------
Sent automatically by SmartPOS''';

    print('📝 Generated message:');
    print('--- GENERATED MESSAGE START ---');
    print(message);
    print('--- GENERATED MESSAGE END ---');
    print('📝 Message length: ${message.length} characters');
    
    return message;
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}