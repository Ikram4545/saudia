import 'dart:async';
import 'package:flutter/material.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import 'package:startapp_sdk/startapp.dart';

/// Central Ad Configuration & Initialization State Machine for Driving Care
class DrivingCareAds {
  // --- CREDENTIALS (VERIFIED FROM DASHBOARDS) ---
  static const String unityGameId = '800419412';
  static const String unityBannerPlacement = 'BP_Banner_Android';
  static const String startIoAppId = '210268325';

  /// Toggle test mode for isolated debugging.
  /// Set to true to verify SDK network rendering; false for production live bidding.
  static const bool useTestAds = false;

  // --- UNITY ADS INITIALIZATION STATE ---
  static final ValueNotifier<UnityInitState> unityInitState =
      ValueNotifier<UnityInitState>(UnityInitState.notInitialized);

  static String? unityInitErrorMessage;
  static bool get isUnityReady => unityInitState.value == UnityInitState.initialized;

  /// Dedicated SDK Initialization Routine - Called and awaited in main()
  static Future<void> initialize() async {
    debugPrint('====================================================');
    debugPrint('[DrivingCareAds] Starting Ad Network Initialization');
    debugPrint('[DrivingCareAds] Mode: ${useTestAds ? "TEST MODE" : "LIVE PRODUCTION"}');
    debugPrint('[DrivingCareAds] Unity Game ID: $unityGameId');
    debugPrint('[DrivingCareAds] Start.io App ID: $startIoAppId');
    debugPrint('====================================================');

    // 1. Configure Start.io via official Flutter plugin
    try {
      final startApp = StartAppSdk();
      await startApp.setTestAdsEnabled(useTestAds);
      debugPrint('[DrivingCareAds] Start.io SDK testMode set to: $useTestAds');
    } catch (e) {
      debugPrint('[DrivingCareAds] Start.io configuration error: $e');
    }

    // 2. Initialize Unity Ads with full callback state-tracking (No arbitrary timeout)
    unityInitState.value = UnityInitState.initializing;
    try {
      await UnityAds.init(
        gameId: unityGameId,
        testMode: useTestAds,
        onComplete: () {
          unityInitState.value = UnityInitState.initialized;
          unityInitErrorMessage = null;
          debugPrint('[DrivingCareAds] >>> Unity Ads SDK Initialized Successfully <<<');
        },
        onFailed: (error, message) {
          unityInitState.value = UnityInitState.failed;
          unityInitErrorMessage = '$error: $message';
          debugPrint('[DrivingCareAds] >>> Unity Ads Initialization FAILED: $error - $message <<<');
        },
      );
    } catch (e) {
      unityInitState.value = UnityInitState.failed;
      unityInitErrorMessage = e.toString();
      debugPrint('[DrivingCareAds] Unity Ads initialization exception: $e');
    }
  }
}

enum UnityInitState {
  notInitialized,
  initializing,
  initialized,
  failed,
}

/// ============================================================================
/// PART 3: START.IO TOP BANNER WIDGET
/// ============================================================================
class StartIoTopBanner extends StatefulWidget {
  const StartIoTopBanner({super.key});

  @override
  State<StartIoTopBanner> createState() => _StartIoTopBannerState();
}

class _StartIoTopBannerState extends State<StartIoTopBanner> {
  final StartAppSdk _startAppSdk = StartAppSdk();
  StartAppBannerAd? _bannerAd;
  bool _isLoading = false;
  String? _lastError;
  int _requestCount = 0;

  @override
  void initState() {
    super.initState();
    _requestBannerAd();
    // NOTE: Automatic periodic refresh is TEMPORARILY DISABLED as per audit
    // instructions to ensure clean, isolated testing of the ad request lifecycle.
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  void _requestBannerAd() {
    if (_isLoading) return;
    _isLoading = true;
    _requestCount++;

    final requestTimestamp = DateTime.now().toIso8601String();
    debugPrint('[Start.io] [$requestTimestamp] Request #$_requestCount sent for Banner (App ID: ${DrivingCareAds.startIoAppId})');

    _startAppSdk
        .loadBannerAd(
      StartAppBannerType.BANNER,
      onAdImpression: () {
        debugPrint('[Start.io] Banner Impression Logged at ${DateTime.now().toIso8601String()}');
      },
      onAdClicked: () {
        debugPrint('[Start.io] Banner Clicked at ${DateTime.now().toIso8601String()}');
      },
    )
        .then((banner) {
      debugPrint('[Start.io] Banner Loaded Successfully at ${DateTime.now().toIso8601String()}');
      if (mounted) {
        setState(() {
          _bannerAd?.dispose();
          _bannerAd = banner;
          _isLoading = false;
          _lastError = null;
        });
      }
    }).catchError((err) {
      final errorMsg = err.toString();
      debugPrint('[Start.io] Banner Request Failed: $errorMsg');
      if (errorMsg.contains('204') || errorMsg.contains('failed_to_receive_ad')) {
        debugPrint('[Start.io] Response: NO_FILL (204) - No ad inventory available from bidders for this device/geo');
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _lastError = errorMsg;
        });
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _lastError != null ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isLoading
                        ? 'Connecting to Start.io Ad Network...'
                        : (_lastError != null ? 'Start.io: No Fill (Waiting for Bids)' : 'Driving Care Partner Network'),
                    style: const TextStyle(
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

/// ============================================================================
/// PART 2: UNITY ADS BOTTOM BANNER WIDGET
/// ============================================================================
class UnityBottomBanner extends StatefulWidget {
  const UnityBottomBanner({super.key});

  @override
  State<UnityBottomBanner> createState() => _UnityBottomBannerState();
}

class _UnityBottomBannerState extends State<UnityBottomBanner> {
  bool _bannerLoaded = false;
  String? _bannerError;

  @override
  void initState() {
    super.initState();
    // NOTE: Automatic periodic refresh is TEMPORARILY DISABLED as per audit
    // instructions to ensure clean, isolated testing of the ad request lifecycle.
  }

  void _onBannerLoaded(String placementId) {
    debugPrint('[Unity Ads] >>> Banner LOADED SUCCESS: placementId=$placementId at ${DateTime.now().toIso8601String()} <<<');
    if (mounted) {
      setState(() {
        _bannerLoaded = true;
        _bannerError = null;
      });
    }
  }

  void _onBannerFailed(String placementId, UnityAdsBannerError error, String message) {
    debugPrint('[Unity Ads] >>> Banner LOAD FAILED: placementId=$placementId, error=$error, message="$message" <<<');
    if (error == UnityAdsBannerError.noFill || message.toLowerCase().contains('no fill')) {
      debugPrint('[Unity Ads] Diagnosis: NO_FILL - The Unity ad exchange has no filled bids for this direct APK at this moment.');
    } else if (message.toLowerCase().contains('not initialized') || message.toLowerCase().contains('initialize')) {
      debugPrint('[Unity Ads] Diagnosis: NOT_INITIALIZED - Unity Ads SDK was not ready before banner request.');
    }
    if (mounted) {
      setState(() {
        _bannerLoaded = false;
        _bannerError = '$error: $message';
      });
    }
  }

  void _onBannerClicked(String placementId) {
    debugPrint('[Unity Ads] Banner Clicked: placementId=$placementId');
  }

  void _onBannerShown(String placementId) {
    debugPrint('[Unity Ads] Banner Shown (Impression): placementId=$placementId');
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
        child: ValueListenableBuilder<UnityInitState>(
          valueListenable: DrivingCareAds.unityInitState,
          builder: (context, initState, child) {
            // Rule: Jab tak initialization successful na ho, banner request mat bhejo
            if (initState != UnityInitState.initialized) {
              return Container(
                height: 50,
                width: double.infinity,
                color: const Color(0xFF0F172A),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: initState == UnityInitState.failed ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      initState == UnityInitState.initializing
                          ? 'Initializing Unity Ads SDK...'
                          : (initState == UnityInitState.failed
                              ? 'Unity SDK Init Failed'
                              : 'Waiting for Unity SDK...'),
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              );
            }

            // SDK is Initialized: Render Unity Banner with dedicated callbacks
            return Stack(
              alignment: Alignment.center,
              children: [
                // Baseline status when banner is requesting or returned no fill
                if (!_bannerLoaded)
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
                          decoration: BoxDecoration(
                            color: _bannerError != null ? const Color(0xFFF59E0B) : const Color(0xFF3B82F6),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _bannerError != null
                              ? 'Unity Ads: No Fill (Waiting for Inventory)'
                              : 'Requesting Unity Banner Ad...',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Native Unity Banner Ad View
                UnityBannerAd(
                  placementId: DrivingCareAds.unityBannerPlacement,
                  size: BannerSize.standard,
                  onLoad: _onBannerLoaded,
                  onClick: _onBannerClicked,
                  onShown: _onBannerShown,
                  onFailed: _onBannerFailed,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
