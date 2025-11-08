import 'dart:async';
import 'dart:isolate';
// import 'package:workmanager/workmanager.dart';  // Temporarily disabled due to build issues
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';
import 'package:telephony/telephony.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:workmanager/workmanager.dart' as wm;  // Temporarily disabled due to build issues

class BackgroundSMSService {
  static const String _taskName = 'automated_sms_report';
  static const String _uniqueName = 'sms_report_task';
  
  static Future<void> initialize() async {
    // await Workmanager().initialize(
    //   callbackDispatcher,
    //   isInDebugMode: false,
    // );
    
    // Schedule the periodic task
    // await _schedulePeriodicSMS();  // Temporarily disabled due to build issues
    print('Background SMS service initialization temporarily disabled due to build issues');
  }
  
  static Future<void> _schedulePeriodicSMS() async {
    // Cancel existing tasks (temporarily disabled due to build issues)
    // await Workmanager().cancelByUniqueName(_uniqueName);
    
    // Schedule periodic task that runs every 15 minutes
    // We'll check the time inside the task to send at specific hours (temporarily disabled due to build issues)
    // await Workmanager().registerPeriodicTask(
    //   _uniqueName,
    //   _taskName,
    //   frequency: const Duration(minutes: 15),
    //   constraints: wm.Constraints(
    //     networkType: wm.NetworkType.not_required,
    //     requiresBatteryNotLow: false,
    //     requiresCharging: false,
    //     requiresDeviceIdle: false,
    //     requiresStorageNotLow: false,
    //   ),
    // );
    print('Background SMS scheduling temporarily disabled due to build issues');
  }
  
  static Future<void> cancelScheduledSMS() async {
    // await Workmanager().cancelByUniqueName(_uniqueName);  // Temporarily disabled due to build issues
    print('Background SMS cancellation temporarily disabled due to build issues');
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  // Workmanager().executeTask((task, inputData) async {
  //   try {
  //     if (task == BackgroundSMSService._taskName) {
  //       await _handleAutomatedSMSTask();
  //       return Future.value(true);
  //     }
  //     return Future.value(false);
  //   } catch (e) {
  //     print('Background SMS task error: $e');
  //     return Future.value(false);
  //   }
  // });
  print('Background SMS callback dispatcher temporarily disabled due to build issues');
}

Future<void> _handleAutomatedSMSTask() async {
  final now = DateTime.now();
  final currentHour = now.hour;
  final currentMinute = now.minute;
  
  // Check if it's one of our target times (11:00, 17:00, 20:00)
  // Allow a 15-minute window to account for task scheduling variations
  final targetHours = [11, 17, 20];
  bool shouldSend = false;
  
  for (int targetHour in targetHours) {
    if (currentHour == targetHour && currentMinute >= 0 && currentMinute <= 15) {
      // Check if we already sent today at this hour
      final lastSentKey = 'last_sms_sent_${targetHour}_${DateFormat('yyyy-MM-dd').format(now)}';
      final prefs = await SharedPreferences.getInstance();
      final lastSent = prefs.getString(lastSentKey);
      
      if (lastSent == null) {
        shouldSend = true;
        // Mark as sent for today
        await prefs.setString(lastSentKey, now.toIso8601String());
        break;
      }
    }
  }
  
  if (!shouldSend) {
    return;
  }
  
  try {
    // Get contacts from database
    final contacts = await _getOwnerContacts();
    if (contacts.isEmpty) {
      print('No owner contacts found for automated SMS');
      return;
    }
    
    // Generate sales report message
    final message = await _generateSalesReportMessage();
    
    // Send SMS to all contacts
    final telephony = Telephony.instance;
    
    for (String phoneNumber in contacts) {
      try {
        await telephony.sendSms(
          to: phoneNumber,
          message: message,
        );
        
        print('Automated SMS sent to $phoneNumber: $message');
        
        // Log the SMS
        await _logSMS(phoneNumber, message, 'automated', true);
        
        print('Automated SMS sent successfully to: $phoneNumber');
      } catch (e) {
        print('Failed to send automated SMS to $phoneNumber: $e');
        await _logSMS(phoneNumber, message, 'automated', false);
        
        // Retry after 5 minutes
        Future.delayed(const Duration(minutes: 5), () async {
          try {
            await telephony.sendSms(
              to: phoneNumber,
              message: message,
            );
            print('Automated SMS retry sent to $phoneNumber: $message');
            await _logSMS(phoneNumber, message, 'automated_retry', true);
            print('Automated SMS retry successful to: $phoneNumber');
          } catch (retryError) {
            print('Automated SMS retry failed to $phoneNumber: $retryError');
            await _logSMS(phoneNumber, message, 'automated_retry', false);
          }
        });
      }
    }
  } catch (e) {
    print('Error in automated SMS task: $e');
  }
}

Future<List<String>> _getOwnerContacts() async {
  try {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'smart_pos.db');
    
    final database = await openDatabase(path);
    
    final List<Map<String, dynamic>> maps = await database.query(
      'owner_contacts',
      where: 'is_active = ?',
      whereArgs: [1],
    );
    
    await database.close();
    
    return maps.map((map) => map['phone_number'] as String).toList();
  } catch (e) {
    print('Error getting owner contacts: $e');
    return [];
  }
}

Future<String> _generateSalesReportMessage() async {
  try {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'smart_pos.db');
    
    final database = await openDatabase(path);
    
    // Get currency symbol from settings
    final prefs = await SharedPreferences.getInstance();
    final currencySymbol = prefs.getString('currency_symbol') ?? '₱';
    
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final monthStart = DateFormat('yyyy-MM-01').format(now);
    
    // Get today's sales and profit
    final todayResult = await database.rawQuery('''
      SELECT 
        COALESCE(SUM(s.total_amount), 0) as total_sales,
        COALESCE(SUM(si.quantity * p.cost_price), 0) as total_cost
      FROM sales s
      LEFT JOIN sale_items si ON s.id = si.sale_id
      LEFT JOIN products p ON si.product_id = p.id
      WHERE DATE(s.created_at) = ?
    ''', [today]);
    
    // Get this month's sales and profit
    final monthResult = await database.rawQuery('''
      SELECT 
        COALESCE(SUM(s.total_amount), 0) as total_sales,
        COALESCE(SUM(si.quantity * p.cost_price), 0) as total_cost
      FROM sales s
      LEFT JOIN sale_items si ON s.id = si.sale_id
      LEFT JOIN products p ON si.product_id = p.id
      WHERE DATE(s.created_at) >= ?
    ''', [monthStart]);
    
    await database.close();
    
    final todayData = todayResult.first;
    final monthData = monthResult.first;
    
    final todaySales = (todayData['total_sales'] as num).toDouble();
    final todayCost = (todayData['total_cost'] as num).toDouble();
    final todayProfit = todaySales - todayCost;
    
    final monthSales = (monthData['total_sales'] as num).toDouble();
    final monthCost = (monthData['total_cost'] as num).toDouble();
    final monthProfit = monthSales - monthCost;
    
    final formatter = NumberFormat.currency(
      symbol: currencySymbol,
      decimalDigits: 2,
    );
    
    final message = '''📊 SALES SUMMARY REPORT
📅 ${DateFormat('MMM dd, yyyy').format(now)}

TODAY'S PERFORMANCE:
💰 Revenue: ${formatter.format(todaySales)}
📈 Profit: ${formatter.format(todayProfit)}

THIS MONTH:
💰 Revenue: ${formatter.format(monthSales)}
📈 Profit: ${formatter.format(monthProfit)}

Sent automatically by SmartPOS''';
    
    return message;
  } catch (e) {
    print('Error generating sales report message: $e');
    return 'Error generating sales report. Please check the app.';
  }
}

Future<void> _logSMS(String phoneNumber, String message, String type, bool success) async {
  try {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'smart_pos.db');
    
    final database = await openDatabase(path);
    
    await database.insert(
      'sms_logs',
      {
        'phone_number': phoneNumber,
        'message': message,
        'type': type,
        'status': success ? 'sent' : 'failed',
        'sent_at': DateTime.now().toIso8601String(),
      },
    );
    
    await database.close();
  } catch (e) {
    print('Error logging SMS: $e');
  }
}