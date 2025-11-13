import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, defaultTargetPlatform, TargetPlatform;
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob Service for managing interstitial advertisements
/// Follows AdMob policies and best practices
class AdMobService {
  static final AdMobService _instance = AdMobService._internal();
  factory AdMobService() => _instance;
  AdMobService._internal();

  // Ad Unit IDs
  static const String _androidInterstitialAdUnitId = 'ca-app-pub-9899607523942636/3420885198';
  static const String _iosInterstitialAdUnitId = 'ca-app-pub-9899607523942636/3420885198';
  
  // Test Ad Unit IDs (for development)
  static const String _testInterstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';

  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdReady = false;
  int _numInterstitialLoadAttempts = 0;
  static const int maxFailedLoadAttempts = 3;

  // Counter to show ads after every N transactions (respecting user experience)
  int _transactionCounter = 0;
  static const int _adsShowFrequency = 3; // Show ad after every 3 transactions

  /// Initialize the Mobile Ads SDK
  static Future<void> initialize() async {
    try {
      // Only initialize on mobile platforms (Android/iOS).
      if (kIsWeb || !_isMobilePlatform) {
        print('AdMob disabled: unsupported platform (web/desktop).');
        return;
      }
      await MobileAds.instance.initialize();
      print('AdMob SDK initialized successfully');
    } catch (e) {
      print('Failed to initialize AdMob SDK: $e');
    }
  }

  /// Get the appropriate interstitial ad unit ID based on platform
  String get _interstitialAdUnitId {
    if (kDebugMode) {
      return _testInterstitialAdUnitId; // Use test ads in development
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _androidInterstitialAdUnitId;
      case TargetPlatform.iOS:
        return _iosInterstitialAdUnitId;
      default:
        return _testInterstitialAdUnitId;
    }
  }

  /// Load an interstitial ad
  void loadInterstitialAd() {
    if (kIsWeb || !_isMobilePlatform) {
      print('Skipping interstitial load: unsupported platform (web/desktop).');
      return;
    }
    if (_isInterstitialAdReady) {
      print('Interstitial ad already loaded');
      return;
    }

    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          print('Interstitial ad loaded successfully');
          _interstitialAd = ad;
          _numInterstitialLoadAttempts = 0;
          _isInterstitialAdReady = true;

          // Set up full screen content callback
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (InterstitialAd ad) {
              print('Interstitial ad showed full screen content');
            },
            onAdDismissedFullScreenContent: (InterstitialAd ad) {
              print('Interstitial ad dismissed');
              ad.dispose();
              _isInterstitialAdReady = false;
              _interstitialAd = null;
              // Load next ad
              loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
              print('Interstitial ad failed to show: $error');
              ad.dispose();
              _isInterstitialAdReady = false;
              _interstitialAd = null;
              // Load next ad
              loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('Interstitial ad failed to load: $error');
          _numInterstitialLoadAttempts += 1;
          _interstitialAd = null;
          _isInterstitialAdReady = false;
          
          // Retry loading with exponential backoff
          if (_numInterstitialLoadAttempts < maxFailedLoadAttempts) {
            Future.delayed(
              Duration(seconds: _numInterstitialLoadAttempts * 5),
              () => loadInterstitialAd(),
            );
          }
        },
      ),
    );
  }

  /// Show interstitial ad (respecting user experience - not too frequently)
  /// Returns true if ad was shown, false otherwise
  Future<bool> showInterstitialAd() async {
    if (kIsWeb || !_isMobilePlatform) {
      print('Skipping show interstitial: unsupported platform (web/desktop).');
      return false;
    }
    if (!_isInterstitialAdReady || _interstitialAd == null) {
      print('Interstitial ad not ready');
      loadInterstitialAd(); // Preload for next time
      return false;
    }

    try {
      await _interstitialAd!.show();
      _isInterstitialAdReady = false;
      _interstitialAd = null;
      return true;
    } catch (e) {
      print('Error showing interstitial ad: $e');
      return false;
    }
  }

  /// Show ad after transaction (with frequency control)
  /// This respects user experience by not showing ads too frequently
  Future<void> showAdAfterTransaction() async {
    if (kIsWeb || !_isMobilePlatform) {
      return;
    }
    _transactionCounter++;
    
    // Show ad only after specified number of transactions
    if (_transactionCounter >= _adsShowFrequency) {
      _transactionCounter = 0;
      await showInterstitialAd();
    }
  }

  /// Check if ad is ready to show
  bool get isAdReady => _isInterstitialAdReady;

  /// Dispose of the current interstitial ad
  void disposeInterstitialAd() {
    if (kIsWeb || !_isMobilePlatform) {
      return;
    }
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isInterstitialAdReady = false;
  }

  /// Reset transaction counter (useful for testing)
  void resetTransactionCounter() {
    _transactionCounter = 0;
  }

  // Helper: only Android/iOS should use AdMob
  static bool get _isMobilePlatform {
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }
}

