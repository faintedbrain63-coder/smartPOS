import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'data/datasources/database_helper.dart';
import 'data/repositories/category_repository_impl.dart';
import 'data/repositories/product_repository_impl.dart';
  import 'data/repositories/sale_repository_impl.dart';
  import 'data/repositories/customer_repository_impl.dart';
  import 'data/providers/repository_provider.dart';
  import 'presentation/providers/customer_provider.dart';
import 'presentation/providers/category_provider.dart';
import 'presentation/providers/product_provider.dart';
import 'presentation/providers/sale_provider.dart';
import 'presentation/providers/cart_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/providers/store_provider.dart';
import 'presentation/providers/currency_provider.dart';
import 'presentation/providers/checkout_provider.dart';
import 'presentation/providers/order_provider.dart';
import 'data/repositories/sync_repository_impl.dart';
import 'presentation/providers/sync_provider.dart';
import 'presentation/screens/main_screen.dart';
import 'core/constants/app_constants.dart';
import 'core/services/admob_service.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize SQLite database factory based on platform
    if (kIsWeb) {
      // For web, use the IndexedDB-backed sqflite FFI implementation without web worker
      // to avoid requiring the sqflite_sw.js asset.
      databaseFactory = databaseFactoryFfiWebNoWebWorker;
      print('Initialized sqflite_common_ffi_web (no web worker) for Flutter Web');
    } else if (Platform.isAndroid || Platform.isIOS) {
      // For mobile platforms (Android/iOS), use default sqflite
      print('Running on mobile platform (${Platform.operatingSystem}) - using default sqflite');
    } else {
      // For desktop platforms, use sqflite_common_ffi
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      print('Initialized sqflite_common_ffi for desktop ${Platform.operatingSystem}');
    }
    
    // Reset database connection to ensure migrations run
    print('🔄 Resetting database connection to trigger migrations...');
    await DatabaseHelper().resetDatabase();
    
    // Initialize AdMob SDK
    await AdMobService.initialize();
    
    // Preload first interstitial ad
    AdMobService().loadInterstitialAd();
    await NotificationService.instance.init();
    
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
        
        // RepositoryProvider manages switching between local/remote
        ChangeNotifierProxyProvider<DatabaseHelper, RepositoryProvider>(
          create: (context) => RepositoryProvider(
            Provider.of<DatabaseHelper>(context, listen: false),
          ),
          update: (_, databaseHelper, previous) => 
              previous ?? RepositoryProvider(databaseHelper),
          lazy: false,
        ),
        
        // Legacy concrete implementations for backward compatibility
        ProxyProvider<DatabaseHelper, CategoryRepositoryImpl>(
          update: (_, databaseHelper, __) => CategoryRepositoryImpl(databaseHelper),
        ),
        ProxyProvider<DatabaseHelper, ProductRepositoryImpl>(
          update: (_, databaseHelper, __) => ProductRepositoryImpl(databaseHelper),
        ),
        ProxyProvider<DatabaseHelper, SaleRepositoryImpl>(
          update: (_, databaseHelper, __) => SaleRepositoryImpl(databaseHelper),
        ),
        ProxyProvider<DatabaseHelper, CustomerRepositoryImpl>(
          update: (_, databaseHelper, __) => CustomerRepositoryImpl(databaseHelper),
        ),
        
        // Providers
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
        ),
        
        // CategoryProvider uses RepositoryProvider for dynamic switching
        ChangeNotifierProxyProvider<RepositoryProvider, CategoryProvider>(
          create: (context) => CategoryProvider(
            Provider.of<RepositoryProvider>(context, listen: false).categoryRepository,
          ),
          update: (_, repoProvider, previous) {
            if (previous != null) {
              previous.setRepository(repoProvider.categoryRepository);
              return previous;
            }
            return CategoryProvider(repoProvider.categoryRepository);
          },
          lazy: false,
        ),
        
        // ProductProvider uses RepositoryProvider for dynamic switching
        ChangeNotifierProxyProvider<RepositoryProvider, ProductProvider>(
          create: (context) => ProductProvider(
            Provider.of<RepositoryProvider>(context, listen: false).productRepository,
          ),
          update: (_, repoProvider, previous) {
            if (previous != null) {
              previous.setRepository(repoProvider.productRepository);
              return previous;
            }
            return ProductProvider(repoProvider.productRepository);
          },
          lazy: false,
        ),
        
        // SaleProvider uses RepositoryProvider for dynamic switching
        ChangeNotifierProxyProvider<RepositoryProvider, SaleProvider>(
          create: (context) => SaleProvider(
            Provider.of<RepositoryProvider>(context, listen: false).saleRepository,
          ),
          update: (_, repoProvider, previous) {
            if (previous != null) {
              previous.setRepository(repoProvider.saleRepository);
              return previous;
            }
            return SaleProvider(repoProvider.saleRepository);
          },
          lazy: false,
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
        ChangeNotifierProxyProvider<CustomerRepositoryImpl, CustomerProvider>(
          create: (context) => CustomerProvider(
            Provider.of<CustomerRepositoryImpl>(context, listen: false),
          ),
          update: (_, repo, previous) => previous ?? CustomerProvider(repo),
          lazy: false,
        ),
        // CheckoutProvider uses RepositoryProvider for thin client support
        ChangeNotifierProxyProvider<RepositoryProvider, CheckoutProvider>(
          create: (context) => CheckoutProvider(
            Provider.of<RepositoryProvider>(context, listen: false).saleRepository,
            Provider.of<RepositoryProvider>(context, listen: false).productRepository,
          ),
          update: (_, repoProvider, previous) {
            if (previous != null) {
              // Update repositories if they changed (client mode switch)
              previous.updateRepositories(
                repoProvider.saleRepository,
                repoProvider.productRepository,
              );
              return previous;
            }
            return CheckoutProvider(
              repoProvider.saleRepository,
              repoProvider.productRepository,
            );
          },
        ),
        // OrderProvider uses RepositoryProvider for thin client support
        ChangeNotifierProxyProvider<RepositoryProvider, OrderProvider>(
          create: (context) => OrderProvider(
            Provider.of<RepositoryProvider>(context, listen: false).saleRepository,
          ),
          update: (_, repoProvider, previous) {
            if (previous != null) {
              previous.updateRepository(repoProvider.saleRepository);
              return previous;
            }
            return OrderProvider(repoProvider.saleRepository);
          },
        ),
        ProxyProvider<DatabaseHelper, SyncRepositoryImpl>(
          update: (_, databaseHelper, __) => SyncRepositoryImpl(databaseHelper),
        ),
        
        // SyncProvider with callback to RepositoryProvider
        ChangeNotifierProxyProvider<RepositoryProvider, SyncProvider>(
          create: (context) {
            final syncProvider = SyncProvider();
            final repoProvider = Provider.of<RepositoryProvider>(context, listen: false);
            
            // Wire up callback to switch repositories when sync mode changes
            syncProvider.onSyncModeChanged = (isClientMode, serverUrl, apiKey) {
              if (isClientMode && serverUrl != null && apiKey != null) {
                repoProvider.enableClientMode(serverUrl, apiKey);
              } else {
                repoProvider.disableClientMode();
              }
            };
            
            return syncProvider;
          },
          update: (_, repoProvider, previous) {
            if (previous != null) {
              // Re-wire callback in case RepositoryProvider was recreated
              previous.onSyncModeChanged = (isClientMode, serverUrl, apiKey) {
                if (isClientMode && serverUrl != null && apiKey != null) {
                  repoProvider.enableClientMode(serverUrl, apiKey);
                } else {
                  repoProvider.disableClientMode();
                }
              };
            }
            return previous ?? SyncProvider();
          },
          lazy: false,
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
               title: AppConstants.appName,
               debugShowCheckedModeBanner: false,
               theme: themeProvider.currentTheme,
               home: const MainScreen(),
               routes: const {},
             );
         },
      ),
    );
  }
}

