import 'package:flutter/foundation.dart';
import '../../domain/entities/owner_contact.dart';
import '../../domain/entities/sms_log.dart';
import '../../domain/repositories/contact_repository.dart';
import '../../domain/repositories/sms_log_repository.dart';
import '../../core/services/sms_service.dart';

class ContactProvider with ChangeNotifier {
  final ContactRepository _contactRepository;
  final SmsLogRepository _smsLogRepository;
  final SmsService _smsService;

  ContactProvider(
    this._contactRepository,
    this._smsLogRepository,
    this._smsService,
  );

  List<OwnerContact> _contacts = [];
  List<SmsLog> _smsLogs = [];
  bool _isLoading = false;
  bool _isSending = false;
  String? _error;

  List<OwnerContact> get contacts => _contacts;
  List<SmsLog> get smsLogs => _smsLogs;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get error => _error;

  Future<void> loadContacts() async {
    _setLoading(true);
    _setError(null);

    try {
      _contacts = await _contactRepository.getAllContacts();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load contacts: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> addContact(OwnerContact contact) async {
    _setError(null);

    try {
      // Check if contact number already exists
      final exists = await _contactRepository.contactExists(contact.contactNumber);
      if (exists) {
        _setError('Contact with this number already exists');
        return false;
      }

      final id = await _contactRepository.insertContact(contact);
      if (id > 0) {
        await loadContacts(); // Reload to get updated list
        return true;
      }
      return false;
    } catch (e) {
      _setError('Failed to add contact: ${e.toString()}');
      return false;
    }
  }

  Future<bool> updateContact(OwnerContact contact) async {
    _setError(null);

    try {
      final result = await _contactRepository.updateContact(contact);
      if (result > 0) {
        await loadContacts(); // Reload to get updated list
        return true;
      }
      return false;
    } catch (e) {
      _setError('Failed to update contact: ${e.toString()}');
      return false;
    }
  }

  Future<bool> deleteContact(int id) async {
    _setError(null);

    try {
      final result = await _contactRepository.deleteContact(id);
      if (result > 0) {
        await loadContacts(); // Reload to get updated list
        return true;
      }
      return false;
    } catch (e) {
      _setError('Failed to delete contact: ${e.toString()}');
      return false;
    }
  }

  Future<bool> sendSmsToContact(int contactId, String message) async {
    _setSending(true);
    _setError(null);

    try {
      final contact = await _contactRepository.getContactById(contactId);
      if (contact == null) {
        _setError('Contact not found');
        return false;
      }

      // Create SMS log entry with pending status
      final smsLog = SmsLog(
        id: 0,
        contactId: contactId,
        messageContent: message,
        status: 'pending',
        sentAt: null,
        createdAt: DateTime.now(),
      );

      final logId = await _smsLogRepository.insertSmsLog(smsLog);

      // Send SMS
      final success = await _smsService.sendSms(contact.contactNumber, message);

      // Update SMS log status
      if (success) {
        await _smsLogRepository.updateSmsLogStatus(logId, 'sent');
      } else {
        await _smsLogRepository.updateSmsLogStatus(logId, 'failed');
        _setError('Failed to send SMS');
      }

      await loadSmsLogs(); // Reload SMS logs
      return success;
    } catch (e) {
      _setError('Failed to send SMS: ${e.toString()}');
      return false;
    } finally {
      _setSending(false);
    }
  }

  Future<bool> sendSmsToAllContacts(String message) async {
    if (_contacts.isEmpty) {
      _setError('No contacts available to send SMS');
      return false;
    }

    _setSending(true);
    _setError(null);

    try {
      final phoneNumbers = _contacts.map((contact) => contact.contactNumber).toList();
      print('Sending SMS to ${phoneNumbers.length} contacts: ${phoneNumbers.join(', ')}');
      
      // Create SMS log entries for all contacts
      final logIds = <int>[];
      for (final contact in _contacts) {
        final smsLog = SmsLog(
          id: 0,
          contactId: contact.id!,
          messageContent: message,
          status: 'pending',
          sentAt: null,
          createdAt: DateTime.now(),
        );
        final logId = await _smsLogRepository.insertSmsLog(smsLog);
        logIds.add(logId);
      }

      // Send SMS to all contacts individually for better error handling
      bool allSent = true;
      final failedContacts = <String>[];
      
      for (int i = 0; i < _contacts.length; i++) {
        final contact = _contacts[i];
        final logId = logIds[i];
        
        try {
          final success = await _smsService.sendSms(contact.contactNumber, message);
          
          if (success) {
            await _smsLogRepository.updateSmsLogStatus(logId, 'sent');
            print('SMS sent successfully to ${contact.name} (${contact.contactNumber})');
          } else {
            await _smsLogRepository.updateSmsLogStatus(logId, 'failed');
            failedContacts.add('${contact.name} (${contact.contactNumber})');
            allSent = false;
            print('Failed to send SMS to ${contact.name} (${contact.contactNumber})');
          }
        } catch (e) {
          await _smsLogRepository.updateSmsLogStatus(logId, 'failed');
          failedContacts.add('${contact.name} (${contact.contactNumber})');
          allSent = false;
          print('Error sending SMS to ${contact.name} (${contact.contactNumber}): $e');
        }
        
        // Add small delay between messages to avoid rate limiting
        if (i < _contacts.length - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      if (!allSent && failedContacts.isNotEmpty) {
        _setError('Failed to send message to: ${failedContacts.join(', ')}. Please try again.');
      }

      await loadSmsLogs(); // Reload SMS logs
      return allSent;
    } catch (e) {
      _setError('Failed to send SMS: ${e.toString()}');
      print('Error in sendSmsToAllContacts: $e');
      return false;
    } finally {
      _setSending(false);
    }
  }

  Future<bool> sendSalesReport(SalesReportData salesData) async {
    try {
      print('📝 Starting sendSalesReport...');
      print('   📊 Sales Data Validation:');
      print('      - Today Revenue: ${salesData.todaySalesRevenue}');
      print('      - Today Profit: ${salesData.todayProfit}');
      print('      - Month Revenue: ${salesData.monthSalesRevenue}');
      print('      - Month Profit: ${salesData.monthProfit}');
      print('      - Currency Symbol: "${salesData.currencySymbol}"');
      
      // Validate sales data
      if (salesData.currencySymbol.isEmpty) {
        print('❌ Currency symbol is empty!');
        _setError('Currency symbol is missing');
        return false;
      }
      
      // Check if we have contacts
      if (_contacts.isEmpty) {
        print('❌ No contacts available for SMS');
        _setError('No contacts available to send SMS');
        return false;
      }
      
      print('✅ Found ${_contacts.length} contacts for SMS');
      
      print('📝 Generating sales report message...');
      final message = _smsService.generateSalesReportMessage(salesData);
      
      print('📱 Generated message details:');
      print('   - Length: ${message.length} characters');
      print('   - Is Empty: ${message.trim().isEmpty}');
      print('   - First 50 chars: "${message.length > 50 ? message.substring(0, 50) : message}..."');
      print('--- FULL MESSAGE START ---');
      print(message);
      print('--- FULL MESSAGE END ---');
      
      if (message.trim().isEmpty) {
        print('❌ Generated message is empty!');
        _setError('Generated sales report message is empty');
        return false;
      }
      
      if (message.length > 1600) {
        print('⚠️ Warning: Message is very long (${message.length} chars), might be split into multiple SMS');
      }
      
      print('📤 Calling sendSmsToAllContacts...');
      final result = await sendSmsToAllContacts(message);
      print('📤 SMS sending result: $result');
      
      if (result) {
        print('✅ Sales report sent successfully to all contacts');
      } else {
        print('❌ Failed to send sales report SMS');
        if (_error == null) {
          _setError('Failed to send sales report SMS - unknown error');
        }
      }
      
      return result;
    } catch (e, stackTrace) {
      print('💥 Exception in sendSalesReport: $e');
      print('📍 Stack trace: $stackTrace');
      _setError('Failed to generate or send sales report: ${e.toString()}');
      return false;
    }
  }

  Future<void> loadSmsLogs() async {
    try {
      _smsLogs = await _smsLogRepository.getAllSmsLogs();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load SMS logs: ${e.toString()}');
    }
  }

  Future<List<SmsLog>> getSmsLogsForContact(int contactId) async {
    try {
      return await _smsLogRepository.getSmsLogsByContactId(contactId);
    } catch (e) {
      _setError('Failed to load SMS logs for contact: ${e.toString()}');
      return [];
    }
  }

  OwnerContact? getContactById(int id) {
    try {
      return _contacts.firstWhere((contact) => contact.id == id);
    } catch (e) {
      return null;
    }
  }

  bool validatePhoneNumber(String phoneNumber) {
    // Philippine phone number validation (09XXXXXXXXX format)
    final regex = RegExp(r'^09\d{9}$');
    return regex.hasMatch(phoneNumber);
  }

  Future<bool> checkSmsPermission() async {
    return await _smsService.hasPermission();
  }

  Future<bool> requestSmsPermission() async {
    return await _smsService.requestPermission();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setSending(bool sending) {
    _isSending = sending;
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
}