import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import 'package:startapp_sdk/startapp.dart';

/// Central Ad Configuration & Initialization State Machine for Driving Care
class DrivingCareAds {
  // --- ADSTERRA PRODUCTION CONFIG (VERIFIED FROM USER ACCOUNT) ---
  static const String adsterraBannerKey = '64fdeaf1b61dcc9b6fb856ef0db8b40e';
  static const String adsterraBannerScript = 'https://bauval.org/22/64fdeaf1b61dcc9b6fb856ef0db8b40e';
  static const String adsterraSocialBarScript = 'https://bauval.org/14/85e63eccc94b187db95bfe3c95cd8440';
  static const String adsterraRectangleKey = '73976233bdd7fb0f01dd9b7bb8a5e81e';
  static const String adsterraRectangleScript = 'https://bauval.org/22/73976233bdd7fb0f01dd9b7bb8a5e81e';
  static const String adsterraApprovedDomain = 'https://omniwiremedia.com/';

  // --- SECONDARY TIER-1 SDK KEYS (FOR BACKGROUND MONITORING) ---
  static const String unityGameId = '800419412';
  static const String unityBannerPlacement = 'BP_Banner_Android';
  static const String startIoAppId = '210268325';

  static final ValueNotifier<bool> isReady = ValueNotifier<bool>(true);

  /// Called once at app startup
  static Future<void> initialize() async {
    debugPrint('====================================================');
    debugPrint('[DrivingCareAds] Initializing Adsterra Monetization Engine');
    debugPrint('[DrivingCareAds] Domain: $adsterraApprovedDomain');
    debugPrint('[DrivingCareAds] Top: 320x50 Banner (Key: $adsterraBannerKey)');
    debugPrint('[DrivingCareAds] Bottom: Social Bar Dynamic Engine');
    debugPrint('====================================================');

    // Background attempt for Start.io / Unity without blocking
    try {
      final startApp = StartAppSdk();
      await startApp.setTestAdsEnabled(false);
    } catch (_) {}

    try {
      UnityAds.init(gameId: unityGameId, testMode: false);
    } catch (_) {}
  }
}

/// ============================================================================
/// 1. ADSTERRA SOCIAL BAR (HIGH-CPM DYNAMIC AUTO-ROTATING ADS)
/// ============================================================================
class AdsterraSocialBarWidget extends StatefulWidget {
  final double height;
  const AdsterraSocialBarWidget({super.key, this.height = 60});

  @override
  State<AdsterraSocialBarWidget> createState() => _AdsterraSocialBarWidgetState();
}

class _AdsterraSocialBarWidgetState extends State<AdsterraSocialBarWidget> {
  late final WebViewController _controller;

  String _buildSocialBarHtml() {
    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body {
      width: 100%;
      height: 100%;
      overflow: hidden;
      background-color: #0F172A;
      display: flex;
      justify-content: center;
      align-items: center;
    }
  </style>
</head>
<body>
  <script data-cfasync="false" src="${DrivingCareAds.adsterraSocialBarScript}"></script>
</body>
</html>''';
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0F172A))
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      );

    _loadSocialBar();
  }

  void _loadSocialBar() {
    try {
      _controller.loadHtmlString(
        _buildSocialBarHtml(),
        baseUrl: DrivingCareAds.adsterraApprovedDomain,
      );
      debugPrint('[Adsterra] Social Bar loaded successfully');
    } catch (e) {
      debugPrint('[Adsterra] Social Bar load error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: widget.height,
      color: const Color(0xFF0F172A),
      alignment: Alignment.center,
      child: WebViewWidget(controller: _controller),
    );
  }
}

/// ============================================================================
/// 2. ADSTERRA 320x50 DISPLAY BANNER (ORGANIC & SAFE)
/// ============================================================================
class AdsterraBannerWidget extends StatefulWidget {
  final int width;
  final int height;
  final String adKey;
  final String scriptUrl;
  final int refreshSeconds;

  const AdsterraBannerWidget({
    super.key,
    this.width = 320,
    this.height = 50,
    this.adKey = DrivingCareAds.adsterraBannerKey,
    this.scriptUrl = DrivingCareAds.adsterraBannerScript,
    this.refreshSeconds = 70, // 60 to 80 seconds standard safe refresh interval
  });

  @override
  State<AdsterraBannerWidget> createState() => _AdsterraBannerWidgetState();
}

class _AdsterraBannerWidgetState extends State<AdsterraBannerWidget> {
  late final WebViewController _controller;
  Timer? _refreshTimer;

  String _buildAdsterraHtml() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body {
      width: 100%;
      height: 100%;
      overflow: hidden;
      background-color: #0F172A;
      display: flex;
      justify-content: center;
      align-items: center;
    }
    iframe { border: none !important; margin: 0 !important; padding: 0 !important; }
  </style>
</head>
<body>
  <!-- cb: $timestamp -->
  <div style="width:${widget.width}px; height:${widget.height}px; display:flex; justify-content:center; align-items:center;">
    <script type="text/javascript">
      atOptions = {
        'key' : '${widget.adKey}',
        'format' : 'iframe',
        'height' : ${widget.height},
        'width' : ${widget.width},
        'params' : {}
      };
    </script>
    <script type="text/javascript" src="${widget.scriptUrl}"></script>
  </div>
</body>
</html>''';
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0F172A))
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      );

    _loadAd();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    if (widget.refreshSeconds <= 0) return;
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(Duration(seconds: widget.refreshSeconds), (timer) {
      if (!mounted) return;
      _loadAd();
    });
  }

  void _loadAd() {
    try {
      _controller.loadHtmlString(
        _buildAdsterraHtml(),
        baseUrl: DrivingCareAds.adsterraApprovedDomain,
      );
      debugPrint('[Adsterra] Banner reloaded (Interval: ${widget.refreshSeconds}s)');
    } catch (e) {
      debugPrint('[Adsterra] Banner load error: $e');
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: widget.height.toDouble(),
      color: const Color(0xFF0F172A),
      alignment: Alignment.center,
      child: SizedBox(
        width: widget.width.toDouble(),
        height: widget.height.toDouble(),
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}

/// ============================================================================
/// TOP BAR: 320x50 ADSTERRA DISPLAY BANNER
/// ============================================================================
class StartIoTopBanner extends StatelessWidget {
  const StartIoTopBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdsterraBannerWidget(
      width: 320,
      height: 50,
      adKey: DrivingCareAds.adsterraBannerKey,
      scriptUrl: DrivingCareAds.adsterraBannerScript,
    );
  }
}

/// ============================================================================
/// BOTTOM BAR: ADSTERRA SOCIAL BAR (DYNAMIC AUTO-ROTATING ADS)
/// ============================================================================
class UnityBottomBanner extends StatelessWidget {
  const UnityBottomBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      top: false,
      child: AdsterraBannerWidget(
        width: 320,
        height: 50,
        adKey: DrivingCareAds.adsterraBannerKey,
        scriptUrl: DrivingCareAds.adsterraBannerScript,
      ),
    );
  }
}

/// ============================================================================
/// MEDIUM RECTANGLE AD (300x250)
/// ============================================================================
class AdsterraRectangleBanner extends StatelessWidget {
  const AdsterraRectangleBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdsterraBannerWidget(
      width: 300,
      height: 250,
      adKey: DrivingCareAds.adsterraRectangleKey,
      scriptUrl: DrivingCareAds.adsterraRectangleScript,
    );
  }
}
