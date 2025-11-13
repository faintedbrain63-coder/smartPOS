import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';

class DonationScreen extends StatelessWidget {
  const DonationScreen({super.key});

  static final Uri _paypalUri = Uri.parse('https://paypal.me/faintedbrain63');

  Future<void> _openPaypal(BuildContext context) async {
    try {
      final ok = await launchUrl(_paypalUri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open PayPal link.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening PayPal: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Donate'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.paddingMedium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Support the Developer',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppConstants.spacingSmall),
                    Text(
                      "If you're enjoying the app, you can donate to support the developer in creating more free mobile apps. Any amount is highly appreciated. God bless!",
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppConstants.spacingLarge),
            Text(
              'GCash (QR Code)',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppConstants.spacingSmall),
            Card(
              elevation: 2,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // The image is expected at project root and registered in pubspec.yaml
                  Image.asset(
                    'my_gcash.jpeg',
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: AppConstants.spacingSmall),
                  Padding(
                    padding: const EdgeInsets.all(AppConstants.paddingSmall),
                    child: Text(
                      'Scan the QR in your GCash app to donate.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppConstants.spacingLarge),
            Text(
              'PayPal',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppConstants.spacingSmall),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.paddingMedium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Donate via PayPal.me',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: AppConstants.spacingSmall),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Open PayPal'),
                        onPressed: () => _openPaypal(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}