import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/backup_service.dart';
import '../../../data/datasources/database_helper.dart';
import '../../providers/theme_provider.dart';
import '../../providers/store_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/sale_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final storeProvider = Provider.of<StoreProvider>(context);
    final currencyProvider = Provider.of<CurrencyProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.spacingMedium),
        children: [
          // Store Information Section
          _buildSettingsSection(
            context,
            'Store Information',
            Icons.store_outlined,
            [
              _buildSettingsTile(
                context,
                icon: Icons.store,
                title: 'Store Name',
                subtitle: storeProvider.storeName,
                onTap: () => _showEditStoreNameDialog(context, storeProvider),
              ),
              _buildSettingsTile(
                context,
                icon: Icons.attach_money,
                title: 'Currency',
                subtitle: '${currencyProvider.selectedCurrency.name} (${currencyProvider.selectedCurrency.symbol})',
                onTap: () => _showCurrencySelectionDialog(context, currencyProvider),
              ),
            ],
          ),
          
          const SizedBox(height: AppConstants.spacingLarge),

          // Theme Section
          _buildSettingsSection(
            context,
            'Appearance',
            Icons.palette_outlined,
            [
              _buildSettingsTile(
                context,
                icon: themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                title: 'Dark Mode',
                subtitle: themeProvider.isDarkMode ? 'Enabled' : 'Disabled',
                trailing: Switch.adaptive(
                  value: themeProvider.isDarkMode,
                  onChanged: (value) {
                    themeProvider.toggleTheme();
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: AppConstants.spacingLarge),

          // Communication Section
          _buildSettingsSection(
            context,
            'Communication',
            Icons.message_outlined,
            [
              _buildSettingsTile(
                context,
                icon: Icons.contacts_outlined,
                title: 'Contact No.',
                subtitle: 'Manage owner contacts for SMS reports',
                onTap: () => Navigator.pushNamed(context, '/owner-contacts'),
                iconColor: Colors.orange,
              ),
            ],
          ),
          
          const SizedBox(height: AppConstants.spacingLarge),

          // Data Management Section
          _buildSettingsSection(
            context,
            'Data Management',
            Icons.storage_outlined,
            [
              _buildSettingsTile(
                context,
                icon: Icons.backup_outlined,
                title: 'Backup Data',
                subtitle: 'Export your data to a file',
                onTap: () => _backupData(context),
                iconColor: Colors.blue,
              ),
              _buildSettingsTile(
                context,
                icon: Icons.restore_outlined,
                title: 'Restore Data',
                subtitle: 'Import data from a backup file',
                onTap: () => _restoreData(context),
                iconColor: Colors.green,
              ),
              _buildSettingsTile(
                context,
                icon: Icons.delete_forever_outlined,
                title: 'Clear All Data',
                subtitle: 'Reset the app and delete all data',
                onTap: () => _showClearDataDialog(context),
                iconColor: Colors.red,
              ),
            ],
          ),
          
          const SizedBox(height: AppConstants.spacingLarge),

          // App Information Section
          _buildSettingsSection(
            context,
            'App Information',
            Icons.info_outline,
            [
              _buildSettingsTile(
                context,
                icon: Icons.apps,
                title: 'App Name',
                subtitle: AppConstants.appName,
                showArrow: false,
              ),
              _buildSettingsTile(
                context,
                icon: Icons.tag,
                title: 'Version',
                subtitle: AppConstants.appVersion,
                showArrow: false,
              ),
              _buildSettingsTile(
                context,
                icon: Icons.business,
                title: 'Company',
                subtitle: AppConstants.companyName,
                showArrow: false,
              ),
            ],
          ),
          
          const SizedBox(height: AppConstants.spacingLarge),

          // Database Information Section
          _buildSettingsSection(
            context,
            'Database Information',
            Icons.storage_outlined,
            [
              _buildSettingsTile(
                context,
                icon: Icons.storage,
                title: 'Database Name',
                subtitle: AppConstants.databaseName,
                showArrow: false,
              ),
              _buildSettingsTile(
                context,
                icon: Icons.numbers,
                title: 'Database Version',
                subtitle: AppConstants.databaseVersion.toString(),
                showArrow: false,
              ),
            ],
          ),
          
          const SizedBox(height: AppConstants.spacingXLarge),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(
    BuildContext context,
    String title,
    IconData sectionIcon,
    List<Widget> children,
  ) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: AppConstants.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppConstants.paddingSmall),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                  ),
                  child: Icon(
                    sectionIcon,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppConstants.spacingMedium),
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingMedium),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    Color? iconColor,
    bool showArrow = true,
  }) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingSmall),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        color: theme.colorScheme.surface.withOpacity(0.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingMedium,
          vertical: AppConstants.paddingSmall,
        ),
        leading: Container(
          padding: const EdgeInsets.all(AppConstants.paddingSmall),
          decoration: BoxDecoration(
            color: (iconColor ?? theme.colorScheme.primary).withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
          ),
          child: Icon(
            icon,
            color: iconColor ?? theme.colorScheme.primary,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: trailing ?? (showArrow && onTap != null
            ? Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              )
            : null),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        ),
      ),
    );
  }

  void _showComingSoonDialog(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(feature),
        content: Text('$feature functionality will be implemented soon.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showEditStoreNameDialog(BuildContext context, StoreProvider storeProvider) {
    final TextEditingController controller = TextEditingController(
      text: storeProvider.storeName,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Store Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Store Name',
            hintText: 'Enter your store name',
          ),
          maxLength: 50,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                final success = await storeProvider.updateStoreName(newName);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'Store name updated successfully'
                            : 'Failed to update store name',
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showCurrencySelectionDialog(BuildContext context, CurrencyProvider currencyProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Currency'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: currencyProvider.availableCurrencies.length,
            itemBuilder: (context, index) {
              final currency = currencyProvider.availableCurrencies[index];
              final isSelected = currency == currencyProvider.selectedCurrency;
              
              return ListTile(
                leading: Text(
                  currency.symbol,
                  style: const TextStyle(fontSize: 20),
                ),
                title: Text(currency.name),
                subtitle: Text(currency.code),
                trailing: isSelected ? const Icon(Icons.check, color: Colors.green) : null,
                onTap: () async {
                  await currencyProvider.updateCurrency(currency);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Currency changed to ${currency.name}'),
                      ),
                    );
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _backupData(BuildContext context) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Creating backup...'),
            ],
          ),
        ),
      );

      final databaseHelper = Provider.of<DatabaseHelper>(context, listen: false);
      final backupService = BackupService(databaseHelper);
      
      final filePath = await backupService.exportData();
      
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        if (filePath != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Backup saved successfully to chosen location'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'OK',
                onPressed: () {},
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Backup creation cancelled'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create backup: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _restoreData(BuildContext context) async {
    // Show confirmation dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Data'),
        content: const Text(
          'This will replace all current data with the backup data. This action cannot be undone.\n\nAre you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Restoring data...'),
            ],
          ),
        ),
      );

      final databaseHelper = Provider.of<DatabaseHelper>(context, listen: false);
      final backupService = BackupService(databaseHelper);
      
      final success = await backupService.pickAndImportData();
      
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        if (success) {
          // Refresh all providers
          final productProvider = Provider.of<ProductProvider>(context, listen: false);
          final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
          final saleProvider = Provider.of<SaleProvider>(context, listen: false);
          
          await Future.wait([
            productProvider.loadProducts(),
            categoryProvider.loadCategories(),
            saleProvider.loadSales(),
          ]);
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Data restored successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Data restore cancelled'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restore data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This will permanently delete all your data including products, categories, and sales. This action cannot be undone.\n\nAre you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _clearAllData(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Clear Data'),
          ),
        ],
      ),
    );
  }

  void _clearAllData(BuildContext context) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Clearing data...'),
            ],
          ),
        ),
      );

      final databaseHelper = Provider.of<DatabaseHelper>(context, listen: false);
      final backupService = BackupService(databaseHelper);
      
      final success = await backupService.clearAllData();
      
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        if (success) {
          // Refresh all providers
          final productProvider = Provider.of<ProductProvider>(context, listen: false);
          final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
          final saleProvider = Provider.of<SaleProvider>(context, listen: false);
          
          await Future.wait([
            productProvider.loadProducts(),
            categoryProvider.loadCategories(),
            saleProvider.loadSales(),
          ]);
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All data cleared successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to clear data'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}