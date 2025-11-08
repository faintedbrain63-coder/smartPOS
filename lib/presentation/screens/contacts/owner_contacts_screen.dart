import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/owner_contact.dart';
import '../../providers/contact_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/sale_provider.dart';
import '../../../core/services/sms_service.dart';

class OwnerContactsScreen extends StatefulWidget {
  const OwnerContactsScreen({super.key});

  @override
  State<OwnerContactsScreen> createState() => _OwnerContactsScreenState();
}

class _OwnerContactsScreenState extends State<OwnerContactsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ContactProvider>(context, listen: false).loadContacts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner Contacts'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddContactDialog(context),
          ),
        ],
      ),
      body: Consumer<ContactProvider>(
        builder: (context, contactProvider, child) {
          if (contactProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (contactProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: AppConstants.spacingMedium),
                  Text(
                    'Error: ${contactProvider.error}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppConstants.spacingMedium),
                  ElevatedButton(
                    onPressed: () {
                      contactProvider.clearError();
                      contactProvider.loadContacts();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // SMS Actions Section
              Container(
                margin: const EdgeInsets.all(AppConstants.spacingMedium),
                padding: const EdgeInsets.all(AppConstants.paddingMedium),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SMS Actions',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacingMedium),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: contactProvider.contacts.isEmpty || contactProvider.isSending
                                ? null
                                : () => _sendSalesReport(context),
                            icon: contactProvider.isSending
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.send),
                            label: Text(contactProvider.isSending ? 'Sending...' : 'Send Sales Report'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppConstants.spacingMedium),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: contactProvider.contacts.isEmpty || contactProvider.isSending
                                ? null
                                : () => _showCustomMessageDialog(context),
                            icon: const Icon(Icons.message),
                            label: const Text('Custom Message'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Contacts List
              Expanded(
                child: contactProvider.contacts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.contacts_outlined,
                              size: 64,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: AppConstants.spacingMedium),
                            Text(
                              'No contacts added yet',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppConstants.spacingSmall),
                            Text(
                              'Add contacts to send SMS reports',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppConstants.spacingLarge),
                            ElevatedButton.icon(
                              onPressed: () => _showAddContactDialog(context),
                              icon: const Icon(Icons.add),
                              label: const Text('Add Contact'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.spacingMedium,
                        ),
                        itemCount: contactProvider.contacts.length,
                        itemBuilder: (context, index) {
                          final contact = contactProvider.contacts[index];
                          return _buildContactCard(context, contact, contactProvider);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContactCard(BuildContext context, OwnerContact contact, ContactProvider contactProvider) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingMedium),
      elevation: AppConstants.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppConstants.paddingMedium),
        leading: Container(
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
          ),
          child: Icon(
            Icons.person,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          contact.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppConstants.spacingSmall),
            Row(
              children: [
                Icon(
                  Icons.phone,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppConstants.spacingSmall),
                Text(
                  contact.contactNumber,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingSmall),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppConstants.spacingSmall),
                Text(
                  'Added ${_formatDate(contact.createdAt ?? DateTime.now())}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _showEditContactDialog(context, contact);
                break;
              case 'delete':
                _showDeleteConfirmationDialog(context, contact, contactProvider);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddContactDialog(BuildContext context) {
    _showContactDialog(context, null);
  }

  void _showEditContactDialog(BuildContext context, OwnerContact contact) {
    _showContactDialog(context, contact);
  }

  void _showContactDialog(BuildContext context, OwnerContact? contact) {
    final nameController = TextEditingController(text: contact?.name ?? '');
    final phoneController = TextEditingController(text: contact?.contactNumber ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(contact == null ? 'Add Contact' : 'Edit Contact'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppConstants.spacingMedium),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '09XXXXXXXXX',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a phone number';
                  }
                  final contactProvider = Provider.of<ContactProvider>(context, listen: false);
                  if (!contactProvider.validatePhoneNumber(value.trim())) {
                    return 'Please enter a valid Philippine phone number (09XXXXXXXXX)';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final contactProvider = Provider.of<ContactProvider>(context, listen: false);
                
                final newContact = OwnerContact(
                  id: contact?.id,
                  name: nameController.text.trim(),
                  contactNumber: phoneController.text.trim(),
                  createdAt: contact?.createdAt ?? DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                bool success;
                if (contact == null) {
                  success = await contactProvider.addContact(newContact);
                } else {
                  success = await contactProvider.updateContact(newContact);
                }

                if (success) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(contact == null ? 'Contact added successfully' : 'Contact updated successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(contactProvider.error ?? 'Failed to save contact'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(contact == null ? 'Add' : 'Update'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, OwnerContact contact, ContactProvider contactProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contact'),
        content: Text('Are you sure you want to delete ${contact.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final success = await contactProvider.deleteContact(contact.id!);
              
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Contact deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(contactProvider.error ?? 'Failed to delete contact'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showCustomMessageDialog(BuildContext context) {
    final messageController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Custom Message'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: messageController,
            decoration: const InputDecoration(
              labelText: 'Message',
              border: OutlineInputBorder(),
            ),
            maxLines: 4,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a message';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop();
                
                final contactProvider = Provider.of<ContactProvider>(context, listen: false);
                
                // Check SMS permission first
                final hasPermission = await contactProvider.checkSmsPermission();
                if (!hasPermission) {
                  // Show friendly permission dialog
                  final shouldRequest = await _showPermissionDialog(context);
                  if (!shouldRequest) {
                    return;
                  }
                  
                  final granted = await contactProvider.requestSmsPermission();
                  if (!granted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('SMS permission is required to send messages'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                }
                
                final success = await contactProvider.sendSmsToAllContacts(messageController.text.trim());
                
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Message sent successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(contactProvider.error ?? 'Failed to send message'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _sendSalesReport(BuildContext context) async {
    print('🚀🚀🚀 === SALES REPORT DEBUG START ===');
    print('🚀 _sendSalesReport called at ${DateTime.now()}');
    
    final contactProvider = Provider.of<ContactProvider>(context, listen: false);
    final saleProvider = Provider.of<SaleProvider>(context, listen: false);
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);

    print('🚀 Providers initialized successfully');
    print('🚀 ContactProvider: ${contactProvider.runtimeType}');
    print('🚀 SaleProvider: ${saleProvider.runtimeType}');
    print('🚀 CurrencyProvider: ${currencyProvider.runtimeType}');

    // Check if there are any contacts first
    print('🔍 Loading contacts...');
    await contactProvider.loadContacts();
    print('🔍 Contacts loaded. Count: ${contactProvider.contacts.length}');
    
    if (contactProvider.contacts.isEmpty) {
      print('❌ No contacts found - showing snackbar and returning');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No saved contacts found. Please add at least one owner contact number.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    print('✅ Found ${contactProvider.contacts.length} contacts:');
    for (int i = 0; i < contactProvider.contacts.length; i++) {
      final contact = contactProvider.contacts[i];
      print('   Contact $i: ${contact.name} - ${contact.contactNumber}');
    }

    // Check SMS permission first
    print('🔐 Checking SMS permission...');
    final hasPermission = await contactProvider.checkSmsPermission();
    print('🔐 SMS permission status: $hasPermission');
    
    if (!hasPermission) {
      print('🔐 No SMS permission - showing permission dialog');
      // Show friendly permission dialog
      final shouldRequest = await _showPermissionDialog(context);
      print('🔐 User permission dialog result: $shouldRequest');
      
      if (!shouldRequest) {
        print('🔐 User declined permission - returning');
        return;
      }
      
      print('🔐 Requesting SMS permission...');
      final granted = await contactProvider.requestSmsPermission();
      print('🔐 SMS permission granted: $granted');
      
      if (!granted) {
        print('❌ SMS permission denied - showing error snackbar');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SMS permission is required to send reports'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    print('✅ SMS permission confirmed');

    try {
      print('📊 === ANALYTICS DATA RETRIEVAL START ===');
      
      // Calculate date ranges
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      
      print('📅 Current time: $now');
      print('📅 Today range: $todayStart to $todayEnd');
      print('📅 Month range: $monthStart to $monthEnd');

      // Get today's sales revenue
      print('💰 Calling getTotalSalesAmount for today...');
      print('💰 Parameters: startDate=$todayStart, endDate=$todayEnd');
      final todayRevenue = await saleProvider.getTotalSalesAmount(
        startDate: todayStart,
        endDate: todayEnd,
      ) ?? 0.0;
      print('💰 Today\'s revenue result: $todayRevenue (type: ${todayRevenue.runtimeType})');
      
      // Get month's sales revenue
      print('💰 Calling getTotalSalesAmount for month...');
      print('💰 Parameters: startDate=$monthStart, endDate=$monthEnd');
      final monthRevenue = await saleProvider.getTotalSalesAmount(
        startDate: monthStart,
        endDate: monthEnd,
      ) ?? 0.0;
      print('💰 Month\'s revenue result: $monthRevenue (type: ${monthRevenue.runtimeType})');
      
      // Calculate today's profit
      print('📈 Calling getTotalProfitAmount for today...');
      print('📈 Parameters: startDate=$todayStart, endDate=$todayEnd');
      final todayProfit = await saleProvider.getTotalProfitAmount(
        startDate: todayStart,
        endDate: todayEnd,
      ) ?? 0.0;
      print('📈 Today\'s profit result: $todayProfit (type: ${todayProfit.runtimeType})');
      
      // Calculate month's profit
      print('📈 Calling getTotalProfitAmount for month...');
      print('📈 Parameters: startDate=$monthStart, endDate=$monthEnd');
      final monthProfit = await saleProvider.getTotalProfitAmount(
        startDate: monthStart,
        endDate: monthEnd,
      ) ?? 0.0;
      print('📈 Month\'s profit result: $monthProfit (type: ${monthProfit.runtimeType})');

      print('📊 === ANALYTICS DATA RETRIEVAL COMPLETE ===');
      print('📊 Final analytics data:');
      print('   📊 Today Revenue: $todayRevenue');
      print('   📊 Today Profit: $todayProfit');
      print('   📊 Month Revenue: $monthRevenue');
      print('   📊 Month Profit: $monthProfit');

      // Get currency symbol
      print('💱 Getting currency symbol...');
      final currencySymbol = currencyProvider.selectedCurrency.symbol;
      print('💱 Currency symbol: "$currencySymbol" (length: ${currencySymbol.length})');

      // Validate that we have valid data
      print('✅ Validating analytics data...');
      if (todayRevenue < 0 || monthRevenue < 0 || todayProfit < 0 || monthProfit < 0) {
        print('⚠️ Warning: Some values are negative, but continuing...');
        print('   ⚠️ Today Revenue negative: ${todayRevenue < 0}');
        print('   ⚠️ Month Revenue negative: ${monthRevenue < 0}');
        print('   ⚠️ Today Profit negative: ${todayProfit < 0}');
        print('   ⚠️ Month Profit negative: ${monthProfit < 0}');
      }

      print('📋 Creating SalesReportData object...');
      final salesData = SalesReportData(
        todaySalesRevenue: todayRevenue,
        todayProfit: todayProfit,
        monthSalesRevenue: monthRevenue,
        monthProfit: monthProfit,
        currencySymbol: currencySymbol,
      );
      print('📋 SalesReportData created successfully');
      print('📋 SalesReportData details:');
      print('   📋 todaySalesRevenue: ${salesData.todaySalesRevenue}');
      print('   📋 todayProfit: ${salesData.todayProfit}');
      print('   📋 monthSalesRevenue: ${salesData.monthSalesRevenue}');
      print('   📋 monthProfit: ${salesData.monthProfit}');
      print('   📋 currencySymbol: "${salesData.currencySymbol}"');

      print('📱 === SMS SENDING START ===');
      print('📱 Calling contactProvider.sendSalesReport...');
      print('📱 Target contacts: ${contactProvider.contacts.length}');
      
      final success = await contactProvider.sendSalesReport(salesData);
      
      print('📱 === SMS SENDING COMPLETE ===');
      print('📱 SMS sending result: $success (type: ${success.runtimeType})');
      
      if (success) {
        print('✅ SUCCESS: Sales report sent successfully');
        print('✅ Showing success snackbar...');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sales report sent successfully to all owner contacts.'),
            backgroundColor: Colors.green,
          ),
        );
        print('✅ Success snackbar shown');
      } else {
        final errorMessage = contactProvider.error ?? 'Failed to send sales report';
        print('❌ FAILURE: Sales report failed to send');
        print('❌ Error message: "$errorMessage"');
        print('❌ ContactProvider error: "${contactProvider.error}"');
        print('❌ Showing error snackbar...');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
        print('❌ Error snackbar shown');
      }
    } catch (e, stackTrace) {
      print('💥💥💥 EXCEPTION in _sendSalesReport:');
      print('💥 Exception type: ${e.runtimeType}');
      print('💥 Exception message: $e');
      print('💥 Stack trace:');
      print(stackTrace.toString());
      print('💥 Showing exception snackbar...');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating sales report: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      print('💥 Exception snackbar shown');
    }
    
    print('🚀🚀🚀 === SALES REPORT DEBUG END ===');
  }

  Future<bool> _showPermissionDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SMS Permission Required'),
        content: const Text('This app needs SMS permission to send reports to owners.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Allow'),
          ),
        ],
      ),
    ) ?? false;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}