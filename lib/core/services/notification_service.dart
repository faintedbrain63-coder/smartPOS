import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _enabled = true;

  Future<void> init() async {
    tz.initializeTimeZones();
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings = InitializationSettings(android: androidSettings, iOS: null, macOS: null);
    await _plugin.initialize(settings);
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'credit_due_channel',
      'Credit Due',
      importance: Importance.high,
    );
    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
  }

  void setEnabled(bool value) {
    _enabled = value;
  }

  Future<void> scheduleCreditDue({required int saleId, required String customerName, required double amount, required DateTime dueDate, int hour = 8}) async {
    if (!_enabled) return;
    final scheduleTime = DateTime(dueDate.year, dueDate.month, dueDate.day, hour);
    if (scheduleTime.isBefore(DateTime.now())) return;
    final tzTime = tz.TZDateTime.from(scheduleTime, tz.local);
    try {
      await _plugin.zonedSchedule(
        saleId,
        'Credit due today',
        '$customerName — ₱${amount.toStringAsFixed(2)}',
        tzTime,
        const NotificationDetails(
          android: AndroidNotificationDetails('credit_due_channel', 'Credit Due', importance: Importance.high),
        ),
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: '$saleId',
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      print('Notification schedule failed: sale=$saleId error=$e');
    }
  }

  Future<void> cancelForSale(int saleId) async {
    try {
      await _plugin.cancel(saleId);
    } catch (e) {
      print('Notification cancel failed: sale=$saleId error=$e');
    }
  }

  Future<void> rescheduleCreditDue({required int saleId, required String customerName, required double amount, required DateTime dueDate, int hour = 8}) async {
    await cancelForSale(saleId);
    await scheduleCreditDue(saleId: saleId, customerName: customerName, amount: amount, dueDate: dueDate, hour: hour);
  }
}