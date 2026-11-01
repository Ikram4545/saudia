import 'dart:async';
import 'package:flutter/material.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import 'package:startapp_sdk/startapp.dart';

/// Central Real Ad Configuration for Driving Care Bot
class DrivingCareAds {
  static const String unityGameId = '800419412';
  static const String unityBannerPlacement = 'BP_Banner_Android';
  static const String startIoAppId = '210268325';

  static bool _unityInitialized = false;
  static bool get isUnityReady => _unityInitialized;

  /// Call once at app launch - awaited before runApp
  static Future<void> initialize() async {
    // 1. Force Start.io to live/production mode
    try {
      final startApp = StartAppSdk();
      await startApp.setTestAdsEnabled(false);
      debugPrint('[DrivingCareAds] Start.io Live Ads mode initialized');
    } catch (e) {
      debugPrint('[DrivingCareAds] Start.io init notice: $e');
    }

    // 2. Initialize Unity Ads in Live mode with completion handshake
    try {
      final completer = Completer<void>();
      await UnityAds.init(
        gameId: unityGameId,
        testMode: false,
        onComplete: () {
          _unityInitialized = true;
          debugPrint('[DrivingCareAds] Unity Ads SDK active (Live Mode)');
          if (!completer.isCompleted) completer.complete();
        },
        onFailed: (error, message) {
          _unityInitialized = false;
          debugPrint('[DrivingCareAds] Unity Ads SDK init: $message');
          if (!completer.isCompleted) completer.complete();
        },
      );
      // Allow up to 2 seconds for native handshake, then proceed
      await completer.future.timeout(const Duration(seconds: 2), onTimeout: () {});
    } catch (e) {
      debugPrint('[DrivingCareAds] Unity Ads init exception: $e');
    }
  }
}

/// REAL AD ENGINE: Top Banner (Start.io Live Network + Auto-Refresh)
class StartIoTopBanner extends StatefulWidget {
  const StartIoTopBanner({super.key});

  @override
  State<StartIoTopBanner> createState() => _StartIoTopBannerState();
}

class _StartIoTopBannerState extends State<StartIoTopBanner> {
  final StartAppSdk _startAppSdk = StartAppSdk();
  StartAppBannerAd? _bannerAd;
  bool _isLoading = false;
  Timer? _retryTimer;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadStartAppAd();

    // Auto-refresh banner every 30 seconds
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _loadStartAppAd(isRefresh: true);
      }
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _autoRefreshTimer?.cancel();
    _bannerAd?.dispose();
    super.dispose();
  }

  void _loadStartAppAd({bool isRefresh = false}) {
    if (_isLoading) return;
    _isLoading = true;

    _startAppSdk
        .loadBannerAd(
      StartAppBannerType.BANNER,
      onAdImpression: () {
        debugPrint('[Start.io] Top Banner impression recorded');
      },
      onAdClicked: () {
        debugPrint('[Start.io] Top Banner clicked');
      },
    )
        .then((banner) {
      if (mounted) {
        setState(() {
          if (isRefresh) {
            _bannerAd?.dispose();
          }
          _bannerAd = banner;
          _isLoading = false;
        });
      }
    }).catchError((err) {
      debugPrint('[Start.io] Real Ad loading notice: $err. Retrying silently...');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        if (!isRefresh && _bannerAd == null) {
          _retryTimer?.cancel();
          _retryTimer = Timer(const Duration(seconds: 4), () => _loadStartAppAd());
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 50,
      color: const Color(0xFF0B132B),
      alignment: Alignment.center,
      child: _bannerAd != null
          ? StartAppBanner(_bannerAd!)
          : Container(
              height: 50,
              width: double.infinity,
              color: const Color(0xFF0F172A),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Driving Care Partner Network',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// REAL AD ENGINE: Bottom Banner (Unity Ads Live + Start.io Live Secondary + Auto-Refresh)
class UnityBottomBanner extends StatefulWidget {
  const UnityBottomBanner({super.key});

  @override
  State<UnityBottomBanner> createState() => _UnityBottomBannerState();
}

class _UnityBottomBannerState extends State<UnityBottomBanner> {
  final StartAppSdk _startAppSdk = StartAppSdk();
  StartAppBannerAd? _secondaryStartAppBanner;
  bool _unityAdLoaded = false;
  int _unityKeyIndex = 0;
  Timer? _unityRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadSecondaryStartApp();

    // Auto-refresh Unity Banner every 32 seconds
    _unityRefreshTimer = Timer.periodic(const Duration(seconds: 32), (_) {
      if (mounted) {
        setState(() {
          _unityKeyIndex++;
        });
      }
    });
  }

  @override
  void dispose() {
    _unityRefreshTimer?.cancel();
    _secondaryStartAppBanner?.dispose();
    super.dispose();
  }

  void _loadSecondaryStartApp() {
    _startAppSdk
        .loadBannerAd(
      StartAppBannerType.BANNER,
      onAdImpression: () {
        debugPrint('[BottomBanner] Secondary Start.io impression recorded');
      },
      onAdClicked: () {
        debugPrint('[BottomBanner] Secondary Start.io clicked');
      },
    )
        .then((banner) {
      if (mounted) {
        setState(() {
          _secondaryStartAppBanner?.dispose();
          _secondaryStartAppBanner = banner;
        });
      }
    }).catchError((_) {
      // Retry in 6s silently if needed
      Future.delayed(const Duration(seconds: 6), () {
        if (mounted && !_unityAdLoaded && _secondaryStartAppBanner == null) {
          _loadSecondaryStartApp();
        }
      });
    });
  }

  void _onUnityFailed(String placementId, UnityAdsBannerError error, String message) {
    debugPrint('[Unity Ads] Bottom Banner response: $message');
    if (mounted && _unityAdLoaded) {
      setState(() {
        _unityAdLoaded = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        height: 50,
        alignment: Alignment.center,
        color: const Color(0xFF0B132B),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // If Unity is still negotiating with DSP, show the real secondary Start.io banner
            if (!_unityAdLoaded && _secondaryStartAppBanner != null)
              StartAppBanner(_secondaryStartAppBanner!),

            // If neither has responded yet, clean branded baseline
            if (!_unityAdLoaded && _secondaryStartAppBanner == null)
              Container(
                height: 50,
                width: double.infinity,
                color: const Color(0xFF0F172A),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF3B82F6),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Driving Care Monetization Engine',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

            // Real Unity Live Banner Ad
            UnityBannerAd(
              key: ValueKey('unity_live_banner_$_unityKeyIndex'),
              placementId: DrivingCareAds.unityBannerPlacement,
              size: BannerSize.standard,
              onLoad: (placementId) {
                debugPrint('[Unity Ads] Real Bottom Banner loaded successfully: $placementId');
                if (mounted) {
                  setState(() {
                    _unityAdLoaded = true;
                  });
                }
              },
              onClick: (placementId) {
                debugPrint('[Unity Ads] Real Bottom Banner clicked: $placementId');
              },
              onFailed: _onUnityFailed,
            ),
          ],
        ),
      ),
    );
  }
}
