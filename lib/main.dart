import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'data/datasources/database_helper.dart';
import 'data/repositories/category_repository_impl.dart';
import 'data/repositories/product_repository_impl.dart';
import 'data/repositories/sale_repository_impl.dart';
import 'data/repositories/contact_repository_impl.dart';
import 'data/repositories/sms_log_repository_impl.dart';
import 'presentation/providers/category_provider.dart';
import 'presentation/providers/product_provider.dart';
import 'presentation/providers/sale_provider.dart';
import 'presentation/providers/cart_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/providers/store_provider.dart';
import 'presentation/providers/currency_provider.dart';
import 'presentation/providers/checkout_provider.dart';
import 'presentation/providers/order_provider.dart';
import 'presentation/providers/contact_provider.dart';
import 'presentation/screens/main_screen.dart';
import 'presentation/screens/contacts/owner_contacts_screen.dart';
import 'core/constants/app_constants.dart';
import 'core/services/sms_service.dart';
import 'core/services/background_sms_service.dart';
import 'core/services/admob_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize SQLite database factory based on platform
    if (kIsWeb) {
      // For web platform, use the default sqflite implementation
      print('Running on web platform - using default database factory');
    } else if (Platform.isAndroid || Platform.isIOS) {
      // For mobile platforms (Android/iOS), use default sqflite
      print('Running on mobile platform (${Platform.operatingSystem}) - using default sqflite');
    } else {
      // For desktop platforms, use sqflite_common_ffi
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      print('Initialized sqflite_common_ffi for desktop ${Platform.operatingSystem}');
    }
    
    // Initialize background SMS service
    await BackgroundSMSService.initialize();
    
    // Initialize AdMob SDK
    await AdMobService.initialize();
    
    // Preload first interstitial ad
    AdMobService().loadInterstitialAd();
    
    runApp(const SmartPOSApp());
  } catch (e) {
    print('Error initializing app: $e');
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Error initializing app: $e'),
        ),
      ),
    ));
  }
}

class SmartPOSApp extends StatelessWidget {
  const SmartPOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Database and Repositories
        Provider<DatabaseHelper>(
          create: (_) => DatabaseHelper(),
          lazy: false, // Initialize immediately
        ),
        ProxyProvider<DatabaseHelper, CategoryRepositoryImpl>(
          update: (_, databaseHelper, __) => CategoryRepositoryImpl(databaseHelper),
        ),
        ProxyProvider<DatabaseHelper, ProductRepositoryImpl>(
          update: (_, databaseHelper, __) => ProductRepositoryImpl(databaseHelper),
        ),
        ProxyProvider<DatabaseHelper, SaleRepositoryImpl>(
          update: (_, databaseHelper, __) => SaleRepositoryImpl(databaseHelper),
        ),
        ProxyProvider<DatabaseHelper, ContactRepositoryImpl>(
          update: (_, databaseHelper, __) => ContactRepositoryImpl(databaseHelper),
        ),
        ProxyProvider<DatabaseHelper, SmsLogRepositoryImpl>(
          update: (_, databaseHelper, __) => SmsLogRepositoryImpl(databaseHelper),
        ),
        
        // Services
        Provider<SmsService>(
          create: (_) => SmsServiceImpl(),
        ),
        
        // Providers
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
        ),
        ChangeNotifierProxyProvider<CategoryRepositoryImpl, CategoryProvider>(
          create: (context) => CategoryProvider(
            Provider.of<CategoryRepositoryImpl>(context, listen: false),
          ),
          update: (_, categoryRepo, previous) => previous ?? CategoryProvider(categoryRepo),
          lazy: false, // Initialize immediately
        ),
        ChangeNotifierProxyProvider<ProductRepositoryImpl, ProductProvider>(
          create: (context) => ProductProvider(
            Provider.of<ProductRepositoryImpl>(context, listen: false),
          ),
          update: (_, productRepo, previous) => previous ?? ProductProvider(productRepo),
          lazy: false, // Initialize immediately
        ),
        ChangeNotifierProxyProvider<SaleRepositoryImpl, SaleProvider>(
          create: (context) => SaleProvider(
            Provider.of<SaleRepositoryImpl>(context, listen: false),
          ),
          update: (_, saleRepo, previous) => previous ?? SaleProvider(saleRepo),
          lazy: false, // Initialize immediately
        ),
        ChangeNotifierProvider<CartProvider>(
          create: (_) => CartProvider(),
        ),
        ChangeNotifierProvider<StoreProvider>(
          create: (_) => StoreProvider(),
        ),
        ChangeNotifierProvider<CurrencyProvider>(
          create: (_) => CurrencyProvider(),
        ),
        ChangeNotifierProxyProvider2<SaleRepositoryImpl, ProductRepositoryImpl, CheckoutProvider>(
          create: (context) => CheckoutProvider(
            Provider.of<SaleRepositoryImpl>(context, listen: false),
            Provider.of<ProductRepositoryImpl>(context, listen: false),
          ),
          update: (_, saleRepo, productRepo, __) => CheckoutProvider(saleRepo, productRepo),
        ),
        ChangeNotifierProvider<OrderProvider>(
          create: (context) => OrderProvider(
            context.read<SaleRepositoryImpl>(),
          ),
        ),
        ChangeNotifierProxyProvider3<ContactRepositoryImpl, SmsLogRepositoryImpl, SmsService, ContactProvider>(
          create: (context) => ContactProvider(
            Provider.of<ContactRepositoryImpl>(context, listen: false),
            Provider.of<SmsLogRepositoryImpl>(context, listen: false),
            Provider.of<SmsService>(context, listen: false),
          ),
          update: (_, contactRepo, smsLogRepo, smsService, __) => ContactProvider(contactRepo, smsLogRepo, smsService),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
               title: AppConstants.appName,
               debugShowCheckedModeBanner: false,
               theme: themeProvider.currentTheme,
               home: const MainScreen(),
               routes: {
                 '/owner-contacts': (context) => const OwnerContactsScreen(),
               },
             );
         },
      ),
    );
  }
}
