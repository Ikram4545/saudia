import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'license_crypto.dart';

void main() {
  runApp(const DrivingCareApp());
}

class DrivingCareApp extends StatefulWidget {
  const DrivingCareApp({super.key});

  @override
  State<DrivingCareApp> createState() => _DrivingCareAppState();
}

class _DrivingCareAppState extends State<DrivingCareApp> {
  bool isDarkMode = false;

  void toggleTheme() {
    setState(() {
      isDarkMode = !isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Driving Care',
      debugShowCheckedModeBanner: false,
      theme: isDarkMode ? _darkTheme : _lightTheme,
      home: DrivingCareHomeScreen(
        isDarkMode: isDarkMode,
        onToggleTheme: toggleTheme,
      ),
    );
  }

  static final ThemeData _lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF6F7FA),
    primaryColor: const Color(0xFF2563EB),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF1E293B),
      elevation: 0.5,
    ),
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF2563EB),
      secondary: Color(0xFF10B981),
      surface: Colors.white,
      onSurface: Color(0xFF1E293B),
    ),
  );

  static final ThemeData _darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF121212),
    primaryColor: const Color(0xFF3B82F6),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E1E1E),
      foregroundColor: Colors.white,
      elevation: 0.5,
    ),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF3B82F6),
      secondary: Color(0xFF10B981),
      surface: Color(0xFF1E1E1E),
      onSurface: Colors.white,
    ),
  );
}

// ---------------------------------------------------------------------------
// DATA MODEL: SAUDI LOCATIONS
// ---------------------------------------------------------------------------
class SaudiLocationItem {
  final String title;
  bool isSelected;

  SaudiLocationItem(this.title, {this.isSelected = false});
}

// ---------------------------------------------------------------------------
// MAIN CONTROLLER & HOME SCREEN
// ---------------------------------------------------------------------------
class DrivingCareHomeScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const DrivingCareHomeScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<DrivingCareHomeScreen> createState() => _DrivingCareHomeScreenState();
}

class _DrivingCareHomeScreenState extends State<DrivingCareHomeScreen> with WidgetsBindingObserver {
  // Method Channel to communicate with Native Android Accessibility Service
  static const platform = MethodChannel('com.drivingcare.saudi/accessibility');

  // Strict Licensing State (Fresh Locked by Default)
  bool isActivated = false; // By default LOCKED until key or trial is entered
  String licenseKey = '';
  String driverName = 'Driver';
  String expiryDisplay = '';
  DateTime? trialExpiresAt;
  bool isTrial = false;
  String lockReason = ''; // If suspended by admin

  final TextEditingController _keyController = TextEditingController();

  // Region & Platform Selection
  bool jeenySelected = true;
  bool uberSelected = true;
  bool boltSelected = false;
  bool cashAccepted = true;
  bool cardAccepted = true;

  // Advanced Bot Settings
  bool runAutoEngine = true;
  bool autoRefresh = true;
  bool autoReject = false;
  bool filterDistance = false;
  String minPrice = '10';
  String maxPrice = '100';
  String maxPickupTime = '10';

  // Native Accessibility Service Status (Genuine defaults from OS)
  bool isAccessibilityActive = false;
  bool batteryOptGranted = false;
  bool overlayGranted = false;
  bool notificationsGranted = false; // Honesty fix: initialized to false

  bool _hasAutoLaunchedJeeny = false;
  bool _openedAccessibilitySettingsOnce = false;

  // Supported packages for Driver Auto-Launch
  static const List<String> jeenyPackages = [
    'me.jeeny.driver',
    'com.jeeny.driver',
    'me.jeeny.captain',
    'com.easytaxi.driver',
  ];
  static const List<String> uberPackages = ['com.ubercab.driver'];
  static const List<String> boltPackages = ['ee.mtakso.driver'];

  // Saudi Blocked Locations
  final List<SaudiLocationItem> allLocations = [
    SaudiLocationItem('Riyadh Dammam Railway / SAR', isSelected: true),
    SaudiLocationItem('Al Bat\'ha (البطحاء)', isSelected: true),
    SaudiLocationItem('Al-Shamisi (الشميسي)', isSelected: true),
    SaudiLocationItem('Manfuhah (منفوحة)', isSelected: true),
    SaudiLocationItem('Airport (مطار)', isSelected: true),
    SaudiLocationItem('Al Safarat (السفارات)', isSelected: false),
    SaudiLocationItem('KAFD / King Abdullah Financial Dist', isSelected: false),
    SaudiLocationItem('KAFD Ring Road', isSelected: false),
    SaudiLocationItem('KAFD Metro Station', isSelected: false),
    SaudiLocationItem('KAFD HQ Tower (Tower 2.14-B)', isSelected: false),
  ];

  List<String> avoidWords = ['Hospital', 'Al Batha'];
  List<String> likedWords = ['KAFD', 'Al Malqa', 'Al Olaya'];

  // Live Domain Server Connection
  String serverUrl = 'https://saudia.pixeltrio.com';
  bool isServerConnected = false;
  Timer? _heartbeatTimer;
  Timer? _countdownTimer;

  // Developer Info (Ikram)
  final String devName = 'Ikram';
  final String devPhone = '03113154649';

  final List<Map<String, dynamic>> orderHistory = [];
  String currentDeviceId = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDeviceId();
    _loadCachedLicense();
    _checkAllPermissions();
    _startTimers();
    _syncSettingsToNativeService(engineOn: true);
  }

  Future<void> _initDeviceId() async {
    try {
      final id = await platform.invokeMethod<String>('getDeviceId');
      if (id != null && id.isNotEmpty) {
        if (mounted) {
          setState(() {
            currentDeviceId = id;
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    _countdownTimer?.cancel();
    _keyController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAllPermissions().then((_) {
        if (_openedAccessibilitySettingsOnce && !isAccessibilityActive) {
          _openedAccessibilitySettingsOnce = false;
          _showRestrictedSettingsGuideDialog();
        }
      });
    }
  }

  Future<void> _checkAllPermissions() async {
    await Future.wait([
      _checkNativeAccessibilityStatus(),
      _checkBatteryOptStatus(),
      _checkOverlayStatus(),
      _checkNotificationStatus(),
    ]);

    if (!mounted) return;

    final allGreen = isAccessibilityActive && batteryOptGranted && overlayGranted && notificationsGranted;
    if (allGreen && isActivated && !_hasAutoLaunchedJeeny) {
      _hasAutoLaunchedJeeny = true;
      // Trigger site 1: Jeeny Auto-Launch via launchPackage when all permissions become green
      _launchTargetDriverApp();
    } else if (!allGreen) {
      _hasAutoLaunchedJeeny = false;
    }
  }

  Future<void> _checkBatteryOptStatus() async {
    try {
      final bool? isExempt = await platform.invokeMethod<bool>('isBatteryOptExempt');
      if (mounted) {
        setState(() {
          batteryOptGranted = isExempt ?? false;
        });
      }
    } catch (_) {}
  }

  Future<void> _checkOverlayStatus() async {
    try {
      final bool? canDraw = await platform.invokeMethod<bool>('canDrawOverlays');
      if (mounted) {
        setState(() {
          overlayGranted = canDraw ?? false;
        });
      }
    } catch (_) {}
  }

  Future<void> _checkNotificationStatus() async {
    try {
      final bool? enabled = await platform.invokeMethod<bool>('areNotificationsEnabled');
      if (mounted && enabled != null) {
        setState(() {
          notificationsGranted = enabled;
        });
      }
    } catch (_) {}
  }

  Future<void> _requestNotificationPermission() async {
    try {
      await platform.invokeMethod('requestNotificationPermission');
      await Future.delayed(const Duration(milliseconds: 400));
      await _checkNotificationStatus();
    } catch (_) {}
  }

  Future<void> _openNotificationSettings() async {
    try {
      await platform.invokeMethod('openNotificationSettings');
    } catch (_) {}
  }

  Future<void> _openBatterySettings() async {
    try {
      await platform.invokeMethod('openBatterySettings');
    } catch (_) {}
  }

  Future<void> _openOverlaySettings() async {
    try {
      await platform.invokeMethod('openOverlaySettings');
    } catch (_) {}
  }

  Future<void> _loadCachedLicense() async {
    try {
      if (currentDeviceId.isEmpty) {
        try {
          currentDeviceId = await platform.invokeMethod<String>('getDeviceId') ?? 'UNKNOWN_DEVICE';
        } catch (_) {
          currentDeviceId = 'UNKNOWN_DEVICE';
        }
      }
      final result = await platform.invokeMethod<Map>('loadLicenseCache');
      if (result != null && result['key'] != null) {
        final key = result['key'].toString();
        final name = result['name']?.toString() ?? 'Driver';
        final days = result['days'] is int ? result['days'] as int : 30;
        final savedAt = result['savedAt'] is int ? result['savedAt'] as int : 0;
        final boundDevId = result['bound_device_id']?.toString() ?? '';

        if (boundDevId.isNotEmpty && currentDeviceId.isNotEmpty && boundDevId != currentDeviceId) {
          if (mounted) {
            setState(() {
              isActivated = false;
              lockReason = 'Ye key kisi aur phone par band hai.';
            });
          }
          return;
        }

        final elapsedDays = savedAt > 0 ? ((DateTime.now().millisecondsSinceEpoch - savedAt) / (86400 * 1000)).floor() : 0;
        final remaining = days - elapsedDays;
        
        if (remaining > 0) {
          setState(() {
            isActivated = true;
            isTrial = false;
            licenseKey = key;
            driverName = name;
            expiryDisplay = '$remaining Din Baqi';
            lockReason = '';
          });
          _syncSettingsToNativeService(engineOn: true);
        }
      }
    } catch (_) {}
  }

  Future<void> _saveLicenseCache({required String key, required String name, required int days, String boundDeviceId = ''}) async {
    try {
      await platform.invokeMethod('saveLicenseCache', {
        'key': key,
        'name': name,
        'days': days,
        'bound_device_id': boundDeviceId.isNotEmpty ? boundDeviceId : currentDeviceId,
      });
    } catch (_) {}
  }

  Future<void> _reportSilentTelemetry(String key, String name, int days) async {
    try {
      if (currentDeviceId.isEmpty) {
        try {
          currentDeviceId = await platform.invokeMethod<String>('getDeviceId') ?? 'UNKNOWN_DEVICE';
        } catch (_) {
          currentDeviceId = 'UNKNOWN_DEVICE';
        }
      }
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      client.userAgent = 'DrivingCareApp/2.4';
      final uri = Uri.parse('$serverUrl/api/ping');
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'key': key,
        'driverName': name,
        'daysLeft': days,
        'deviceId': currentDeviceId,
        'device': 'Android ($currentDeviceId)',
      }));
      final response = await request.close();
      final bodyStr = await response.transform(utf8.decoder).join();
      final data = jsonDecode(bodyStr);

      if (mounted && data is Map) {
        if (data['success'] == false && data['error'] == 'device_mismatch') {
          setState(() {
            isActivated = false;
            lockReason = data['message'] ?? 'Ye key kisi aur phone par band hai.';
          });
          _syncSettingsToNativeService(engineOn: false);
          try {
            platform.invokeMethod('clearLicenseCache');
          } catch (_) {}
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFEF4444),
              content: Text(data['message'] ?? 'Ye key kisi aur phone par band hai.'),
            ),
          );
        }
      }
    } catch (_) {}
  }

  void _startTimers() {
    // 1. Heartbeat every 15s to verify key against Ikram's Laptop Admin Panel
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (t) {
      if (isActivated) {
        _sendHeartbeatCheck();
      } else {
        _pingServer();
      }
    });

    // 2. Countdown timer to check 24-48 hours trial expiry every 10 seconds
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 10), (t) {
      if (isActivated && isTrial && trialExpiresAt != null) {
        final remaining = trialExpiresAt!.difference(DateTime.now());
        if (remaining.isNegative) {
          // TRIAL EXPIRED! Self-Lock immediately!
          setState(() {
            isActivated = false;
            lockReason = 'Aapka 24 se 48 ghantay ka testing trial khatam ho chuka hai.';
          });
          _syncSettingsToNativeService(engineOn: false);
        } else {
          setState(() {
            final hours = remaining.inHours;
            final mins = remaining.inMinutes % 60;
            expiryDisplay = '${hours}h ${mins}m Baqi Hain';
          });
        }
      }
    });
  }

  // Check if native Android accessibility service is ON
  Future<void> _checkNativeAccessibilityStatus() async {
    try {
      final bool? enabled = await platform.invokeMethod<bool>('isAccessibilityEnabled');
      if (mounted) {
        setState(() {
          isAccessibilityActive = enabled ?? false;
        });
      }
    } catch (_) {}
  }

  // Open native Android settings for accessibility
  Future<void> _openNativeAccessibilitySettings() async {
    _openedAccessibilitySettingsOnce = true;
    try {
      await platform.invokeMethod('openAccessibilitySettings');
    } catch (_) {}
  }

  // Open App Details Settings for Android 13/14 "Allow Restricted Settings"
  Future<void> _openAppDetailsSettings() async {
    try {
      await platform.invokeMethod('openAppDetailsSettings');
    } catch (_) {}
  }

  // Launch Target Ride-Hailing Driver App (Jeeny, Uber, Bolt)
  Future<bool> _launchTargetDriverApp({bool isManual = false}) async {
    List<String> pkgs = jeenyPackages;
    String targetName = 'Jeeny';
    if (!jeenySelected && uberSelected) {
      pkgs = uberPackages;
      targetName = 'Uber';
    } else if (!jeenySelected && !uberSelected && boltSelected) {
      pkgs = boltPackages;
      targetName = 'Bolt';
    }

    for (final pkg in pkgs) {
      try {
        final success = await platform.invokeMethod<bool>('launchPackage', {'package': pkg});
        if (success == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$targetName Driver App khol di gayi hai 🚀'),
                backgroundColor: const Color(0xFF10B981),
                duration: const Duration(seconds: 3),
              ),
            );
          }
          return true;
        }
      } catch (_) {}
    }

    if (mounted) {
      _showAppNotInstalledDialog(targetName);
    }
    return false;
  }

  void _showAppNotInstalledDialog(String platformName) {
    final defaultPkg = platformName == 'Uber'
        ? 'com.ubercab.driver'
        : platformName == 'Bolt'
            ? 'ee.mtakso.driver'
            : 'me.jeeny.driver';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text('$platformName App Nahi Mili', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
        content: Text(
          'Aapke mobile mein $platformName Driver App install nahi mili ya package detect nahi ho saka.\n\nPlay Store se $platformName install karein ya confirm karein.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.shop_rounded, size: 18),
            label: const Text('Play Store Kholein'),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await platform.invokeMethod('openPlayStore', {'package': defaultPkg});
              } catch (_) {}
            },
          ),
        ],
      ),
    );
  }

  void _showRestrictedSettingsGuideDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.security_update_warning_rounded, color: Color(0xFFEF4444), size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Accessibility "Restricted" Hai?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Android 13/14 par download ki hui apps mein Accessibility pehle block hoti hai ("Restricted setting"). Isko theek karne ka asaan tareeqa:',
                style: TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 12),
              _guideStep(1, 'Neeche "App Info Kholein" dabayein.'),
              _guideStep(2, 'Upar right kone mein 3 dots (⋮) par tap karein.'),
              _guideStep(3, '"Allow restricted settings" par tap karke phone lock/fingerprint verify karein.'),
              _guideStep(4, 'Wapas Accessibility mein ja kar "Driving Care" ko ON karein.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Samajh Gaya', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.info_outline, size: 18),
            label: const Text('App Info Kholein'),
            onPressed: () {
              Navigator.pop(ctx);
              _openAppDetailsSettings();
            },
          ),
        ],
      ),
    );
  }

  Widget _guideStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: const Color(0xFFEF4444),
            child: Text('$number', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
        ],
      ),
    );
  }

  void _toggleEngineSwitch() {
    if (runAutoEngine) {
      setState(() {
        runAutoEngine = false;
      });
      _syncSettingsToNativeService(engineOn: false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Auto Engine PAUSED')),
      );
      return;
    }

    // Sequence check for missing permissions before turning ON
    if (!isAccessibilityActive) {
      _openNativeAccessibilitySettings();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pehle Accessibility Service ON karein.')),
      );
      return;
    }
    if (!batteryOptGranted) {
      _openBatterySettings();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Battery Optimization Unrestricted karein.')),
      );
      return;
    }
    if (!overlayGranted) {
      _openOverlaySettings();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Display Overlay permission allow karein.')),
      );
      return;
    }
    if (!notificationsGranted) {
      _openNotificationSettings();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notifications permission allow karein.')),
      );
      return;
    }

    setState(() {
      runAutoEngine = true;
    });
    _syncSettingsToNativeService(engineOn: true);
    // Trigger site 2: Jeeny Auto-Launch via launchPackage when engine is switched ON
    _launchTargetDriverApp(isManual: true);
  }

  // Push filter rules to native Kotlin service
  Future<void> _syncSettingsToNativeService({bool? engineOn}) async {
    try {
      final blocked = allLocations.where((l) => l.isSelected).map((l) => l.title).toList();
      await platform.invokeMethod('syncSettings', {
        'runAutoEngine': engineOn ?? runAutoEngine,
        'minPrice': double.tryParse(minPrice) ?? 10.0,
        'maxPrice': double.tryParse(maxPrice) ?? 100.0,
        'maxPickupTime': double.tryParse(maxPickupTime) ?? 10.0,
        'autoReject': autoReject,
        'blockedLocations': blocked,
        'avoidWords': avoidWords,
      });
    } catch (_) {}
  }

  // Direct WhatsApp contact with Ikram
  Future<void> _openWhatsAppContact({String customMsg = ''}) async {
    final msg = customMsg.isNotEmpty
        ? customMsg
        : 'Assalam-o-Alaikum Ikram bhai, mujhe Driving Care app ki License Key chahiye.';
    try {
      await platform.invokeMethod('openWhatsApp', {
        'phone': devPhone,
        'message': msg,
      });
    } catch (_) {}
  }

  // Ping Server to check local connection
  Future<void> _pingServer() async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
      final uri = Uri.parse('$serverUrl/api/ping');
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'key': licenseKey.isEmpty ? 'PING' : licenseKey}));
      final response = await request.close();
      if (mounted) {
        setState(() {
          isServerConnected = (response.statusCode == 200);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          isServerConnected = false;
        });
      }
    }
  }

  // Heartbeat check: Periodic check (Tolerates network drops with zero lockouts)
  Future<void> _sendHeartbeatCheck() async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      client.userAgent = 'DrivingCareApp/2.4';
      final uri = Uri.parse('$serverUrl/api/ping');
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      if (currentDeviceId.isEmpty) {
        try {
          currentDeviceId = await platform.invokeMethod<String>('getDeviceId') ?? 'UNKNOWN_DEVICE';
        } catch (_) {
          currentDeviceId = 'UNKNOWN_DEVICE';
        }
      }
      request.write(jsonEncode({
        'key': licenseKey,
        'driverName': driverName,
        'deviceId': currentDeviceId,
        'device': 'Android ($currentDeviceId)',
      }));
      final response = await request.close();
      final bodyStr = await response.transform(utf8.decoder).join();
      final data = jsonDecode(bodyStr);

      if (mounted && data is Map) {
        if (data['success'] == false && data['error'] == 'device_mismatch') {
          setState(() {
            isActivated = false;
            lockReason = data['message'] ?? 'Ye key kisi aur phone par band hai.';
          });
          _syncSettingsToNativeService(engineOn: false);
          try {
            platform.invokeMethod('clearLicenseCache');
          } catch (_) {}
          return;
        }

        if (response.statusCode == 200 && data['success'] == true) {
          final status = (data['status'] ?? 'active').toString().toLowerCase();
          if (status == 'blocked' || status == 'suspended' || status == 'inactive') {
            // ONLY lock when admin EXPLICITLY revokes access on the server
            setState(() {
              isActivated = false;
              lockReason = 'Admin (Ikram) ne aapka access suspend / lock kar diya hai.';
            });
            _syncSettingsToNativeService(engineOn: false);
            try {
              platform.invokeMethod('clearLicenseCache');
            } catch (_) {}
          } else {
            setState(() {
              isServerConnected = true;
            });
          }
        }
        // NOTE: On any other non-blocked response, keep previous activation active!
      }
    } catch (_) {
      // Network drop, timeout, slow net:
      // STRICT RULE: KABHI LOCK NAHI HOGA! Grace period active, engine chalta rahega!
      if (mounted) {
        setState(() {
          isServerConnected = false;
        });
      }
    }
  }

  // Activate with user-entered key (Pure Offline Ed25519 Cryptographic Verification + Device Binding)
  // FIX B & FIX C: No server login.php fallback, strict signed DCS keys, device bound.
  Future<void> _activateWithKey() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFEF4444),
          content: Text('Barah-e-karam License Key darj karein.'),
        ),
      );
      return;
    }

    // 1. FAST OFFLINE VERIFICATION (Ed25519 Cryptographic Signature)
    final offlineCheck = await DrivingCareCrypto.verifyOfflineKey(key);
    if (!offlineCheck.isValid) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFEF4444),
          content: Text(offlineCheck.errorMessage),
        ),
      );
      return;
    }

    // 2. DEVICE BINDING CHECK (Fix B)
    if (currentDeviceId.isEmpty) {
      try {
        currentDeviceId = await platform.invokeMethod<String>('getDeviceId') ?? 'UNKNOWN_DEVICE';
      } catch (_) {
        currentDeviceId = 'UNKNOWN_DEVICE';
      }
    }

    final cached = await platform.invokeMethod<Map>('loadLicenseCache');
    final storedBoundKey = cached?['key']?.toString() ?? '';
    final storedBoundDeviceId = cached?['bound_device_id']?.toString() ?? '';

    // If this key was bound on this storage to a different device ID
    if (storedBoundKey == offlineCheck.key && storedBoundDeviceId.isNotEmpty && storedBoundDeviceId != currentDeviceId) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFEF4444),
          content: Text('Ye key kisi aur phone par band hai.'),
        ),
      );
      return;
    }

    // Save local binding & cache
    await _saveLicenseCache(
      key: offlineCheck.key,
      name: offlineCheck.driverName,
      days: offlineCheck.daysLeft,
      boundDeviceId: currentDeviceId,
    );

    setState(() {
      isActivated = true;
      isTrial = false;
      licenseKey = offlineCheck.key;
      driverName = offlineCheck.driverName;
      expiryDisplay = '${offlineCheck.daysLeft} Din Baqi';
      lockReason = '';
    });
    _syncSettingsToNativeService(engineOn: true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF10B981),
        content: Text('License Verified! Driving Care Unlocked ✔ (${offlineCheck.driverName})'),
      ),
    );

    // Sync device binding and telemetry with server in background
    _reportSilentTelemetry(offlineCheck.key, offlineCheck.driverName, offlineCheck.daysLeft);
  }

  // Start 48-Hour Trial (With countdown & automatic self-destruct lock)
  Future<void> _startTrial() async {
    final now = DateTime.now();
    final expireDate = now.add(const Duration(hours: 48));

    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
      final uri = Uri.parse('$serverUrl/api/trial');
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'device': 'Driver Mobile (Trial)',
        'phone': 'Pending Trial',
      }));
      final response = await request.close();
      final bodyStr = await response.transform(utf8.decoder).join();
      final data = jsonDecode(bodyStr);

      if (mounted) {
        setState(() {
          isActivated = true;
          isTrial = true;
          trialExpiresAt = expireDate;
          licenseKey = data['driver']?['key'] ?? 'TRIAL-48H';
          driverName = 'Trial User';
          expiryDisplay = '48 Hours Remaining';
          lockReason = '';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          isActivated = true;
          isTrial = true;
          trialExpiresAt = expireDate;
          licenseKey = 'TRIAL-48H';
          driverName = 'Trial User';
          expiryDisplay = '48 Hours Remaining';
          lockReason = '';
        });
      }
    }

    _syncSettingsToNativeService(engineOn: true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFF10B981),
        content: Text('48-Ghantay Ka Trial Shuru! Enjoy full access.'),
      ),
    );
  }


  void _showOrderHistory() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Order History', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: orderHistory.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No orders recorded yet.')),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: orderHistory.length,
                    itemBuilder: (c, idx) {
                      final item = orderHistory[idx];
                      return ListTile(
                        leading: const Icon(Icons.check_circle, color: Color(0xFF10B981)),
                        title: Text('${item['platform']} - ${item['fare']}'),
                        subtitle: Text(item['pickup']),
                        trailing: Text(item['time'], style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CLOSE'),
            ),
          ],
        );
      },
    );
  }

  void _openAdvancedControl() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => AdvancedControlScreen(
          isDarkMode: widget.isDarkMode,
          onToggleTheme: widget.onToggleTheme,
          runAutoEngine: runAutoEngine,
          autoRefresh: autoRefresh,
          autoReject: autoReject,
          filterDistance: filterDistance,
          minPrice: minPrice,
          maxPrice: maxPrice,
          maxPickupTime: maxPickupTime,
          isAccessibilityActive: isAccessibilityActive,
          batteryOptGranted: batteryOptGranted,
          overlayGranted: overlayGranted,
          notificationsGranted: notificationsGranted,
          allLocations: allLocations,
          avoidWords: avoidWords,
          likedWords: likedWords,
          serverUrl: serverUrl,
          licenseKey: licenseKey,
          onOpenAccessibilitySettings: _openNativeAccessibilitySettings,
          onOpenBatterySettings: _openBatterySettings,
          onOpenOverlaySettings: _openOverlaySettings,
          onOpenNotificationSettings: () {
            _requestNotificationPermission();
            _openNotificationSettings();
          },
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        runAutoEngine = result['runAutoEngine'] ?? runAutoEngine;
        autoRefresh = result['autoRefresh'] ?? autoRefresh;
        autoReject = result['autoReject'] ?? autoReject;
        filterDistance = result['filterDistance'] ?? filterDistance;
        minPrice = result['minPrice'] ?? minPrice;
        maxPrice = result['maxPrice'] ?? maxPrice;
        maxPickupTime = result['maxPickupTime'] ?? maxPickupTime;
        avoidWords = List<String>.from(result['avoidWords'] ?? avoidWords);
        likedWords = List<String>.from(result['likedWords'] ?? likedWords);
      });
      // Immediately push updated rules to native Android Accessibility Service!
      _syncSettingsToNativeService();
      if (runAutoEngine && isAccessibilityActive && batteryOptGranted && overlayGranted && notificationsGranted) {
        // Trigger site 2b: Jeeny Auto-Launch via launchPackage when settings applied with engine active
        _launchTargetDriverApp(isManual: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE5E7EB);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'Driving Care',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'v2.4.0',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Toggle Black/White Theme',
            icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              _checkNativeAccessibilityStatus();
              _pingServer();
            },
          ),
        ],
      ),
      body: isActivated ? _buildActiveDashboard(cardBg, borderColor, textPrimary) : _buildLockedScreen(cardBg, borderColor, textPrimary),
      floatingActionButton: isActivated
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              tooltip: 'Open Advanced Control',
              onPressed: _openAdvancedControl,
              child: const Icon(Icons.settings_rounded, size: 28),
            )
          : null,
    );
  }

  // ---------------------------------------------------------------------------
  // VIEW A: STRICT LOCKED / ACCESS REQUIRED SCREEN (For Adnan & New Users)
  // ---------------------------------------------------------------------------
  Widget _buildLockedScreen(Color cardBg, Color borderColor, Color textPrimary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // App Logo / Shield Icon
          Center(
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.security_rounded,
                color: Color(0xFF2563EB),
                size: 50,
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Center(
            child: Text(
              'DRIVING CARE BOT',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const Center(
            child: Text(
              'Smart Driver Assistant for Saudi Arabia (Jeeny & Uber)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 20),

          // Red Locked Status Banner
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    lockReason.isNotEmpty ? lockReason : 'ACCESS LOCKED 🔒 (License Key Required)',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Key Input Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ENTER LICENSE KEY',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _keyController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'e.g. ADNAN-VIP or DC-8921',
                    prefixIcon: const Icon(Icons.vpn_key_rounded, color: Color(0xFF2563EB)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _activateWithKey,
                    child: const Text(
                      'ACTIVATE BOT',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Center(
                  child: Text(
                    '— YA —',
                    style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF10B981),
                      side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.timer_outlined, size: 20),
                    label: const Text(
                      'START 24-48 HOUR TRIAL',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: _startTrial,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Contact Developer Card (Ikram)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.support_agent_rounded, color: Color(0xFF10B981), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Naye User Hain Ya Key Chahiye?',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Developer: $devName\nWhatsApp: $devPhone',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                    label: Text(
                      'Contact $devName on WhatsApp',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _openWhatsAppContact(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // VIEW B: ACTIVE DASHBOARD (Video frame sec_70.jpg exact UI)
  // ---------------------------------------------------------------------------
  Widget _buildActiveDashboard(Color cardBg, Color borderColor, Color textPrimary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Warning Banner: Accessibility Service is OFF
          if (!isAccessibilityActive)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  InkWell(
                    onTap: () {
                      _openNativeAccessibilitySettings();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Settings khul rahi hai. Driving Care ko Turn ON karein!')),
                      );
                    },
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.white, size: 24),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '⚠️ Accessibility Service OFF Hai!\nTap karein aur Driving Care ko Turn ON karein.',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _openAppDetailsSettings,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_open_rounded, color: Colors.white, size: 14),
                          SizedBox(width: 6),
                          Text(
                            'Android 13/14 "Restricted Setting" Grayed out? Tap here',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Trial / Expiry Banner
          if (isTrial)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.amber.shade700,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_top_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '⏳ 24-48h Trial Active: $expiryDisplay',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          // Live Engine & Permissions Status Card (Fix 6: Real status from OS)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Live Engine & Permissions Status',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    InkWell(
                      onTap: _toggleEngineSwitch,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: runAutoEngine
                              ? const Color(0xFF10B981).withOpacity(0.12)
                              : const Color(0xFFEF4444).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: runAutoEngine ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              runAutoEngine ? Icons.play_arrow_rounded : Icons.pause_rounded,
                              size: 14,
                              color: runAutoEngine ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              runAutoEngine ? 'ENGINE ACTIVE' : 'ENGINE PAUSED',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: runAutoEngine ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    InkWell(
                      onTap: () {
                        _openNativeAccessibilitySettings();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Accessibility Settings khul rahi hain...')),
                        );
                      },
                      child: Column(
                        children: [
                          Icon(
                            isAccessibilityActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
                            color: isAccessibilityActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            size: 22,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Accessibility\n${isAccessibilityActive ? "ON ✔" : "OFF ✕"}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                          if (!isAccessibilityActive) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'ON karein ➔',
                                style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        _openBatterySettings();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Battery Optimization Settings khul rahi hain...')),
                        );
                      },
                      child: Column(
                        children: [
                          Icon(
                            batteryOptGranted ? Icons.check_circle_rounded : Icons.cancel_rounded,
                            color: batteryOptGranted ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            size: 22,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Battery\n${batteryOptGranted ? "Exempt ✔" : "Restricted ✕"}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        _openOverlaySettings();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Display Overlay Settings khul rahi hain...')),
                        );
                      },
                      child: Column(
                        children: [
                          Icon(
                            overlayGranted ? Icons.check_circle_rounded : Icons.cancel_rounded,
                            color: overlayGranted ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            size: 22,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Overlay\n${overlayGranted ? "Granted ✔" : "Denied ✕"}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        if (!notificationsGranted) {
                          _requestNotificationPermission();
                          _openNotificationSettings();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Notification settings khul rahi hain, allow karein.')),
                          );
                        }
                      },
                      child: Column(
                        children: [
                          Icon(
                            notificationsGranted ? Icons.check_circle_rounded : Icons.cancel_rounded,
                            color: notificationsGranted ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            size: 22,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Notification\n${notificationsGranted ? "Active ✔" : "Blocked ✕"}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (!notificationsGranted)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_off_rounded, color: Color(0xFFDC2626), size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notifications Blocked Hain!',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF991B1B)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Background mein Jeeny alerts ke liye notification zaroori hai.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF7F1D1D)),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      _requestNotificationPermission();
                      _openNotificationSettings();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('Unlock', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

          // Account Verified Card (sec_70.jpg)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.verified, color: Color(0xFF2563EB), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Account Verified  $licenseKey',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_month_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      'Valid: $expiryDisplay',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text(
                      'LOGOUT / LOCK',
                      style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    onPressed: () {
                      setState(() {
                        isActivated = false;
                        _syncSettingsToNativeService(engineOn: false);
                      });
                    },
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Success! (Group: Driving Care)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),


          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFF334155),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.history_rounded, size: 20),
              label: const Text(
                'VIEW ORDER HISTORY',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
              ),
              onPressed: _showOrderHistory,
            ),
          ),

          const SizedBox(height: 18),

          // Region & App Selection
          Text(
            'Region & App Selection:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Saudi Arabia 🇸🇦', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                Icon(Icons.public_rounded, color: Color(0xFF2563EB), size: 20),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Checkboxes
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: CheckboxListTile(
              value: jeenySelected,
              title: const Text('Jeeny', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              activeColor: const Color(0xFF2563EB),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              onChanged: (val) => setState(() => jeenySelected = val ?? true),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: CheckboxListTile(
              value: uberSelected,
              title: const Text('Uber', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              activeColor: const Color(0xFF2563EB),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              onChanged: (val) => setState(() => uberSelected = val ?? true),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: CheckboxListTile(
              value: boltSelected,
              title: const Text('Bolt', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              activeColor: const Color(0xFF2563EB),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              onChanged: (val) => setState(() => boltSelected = val ?? false),
            ),
          ),

          // Payment toggles
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => cashAccepted = !cashAccepted),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: cashAccepted ? const Color(0xFF10B981) : borderColor,
                        width: cashAccepted ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('💵 Cash', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(width: 8),
                        Icon(
                          cashAccepted ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                          color: cashAccepted ? const Color(0xFF10B981) : Colors.grey,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => cardAccepted = !cardAccepted),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: cardAccepted ? const Color(0xFF10B981) : borderColor,
                        width: cardAccepted ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('💳 Card', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(width: 8),
                        Icon(
                          cardAccepted ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                          color: cardAccepted ? const Color(0xFF10B981) : Colors.grey,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Support Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.headset_mic_rounded, color: Color(0xFF10B981), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Developer Support', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 3),
                      Text('Developer: $devName ($devPhone)', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SCREEN 2: ADVANCED CONTROL SCREEN (Matching sec_101.jpg, sec_125.jpg, sec_141.jpg)
// ---------------------------------------------------------------------------
class AdvancedControlScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  final bool runAutoEngine;
  final bool autoRefresh;
  final bool autoReject;
  final bool filterDistance;
  final String minPrice;
  final String maxPrice;
  final String maxPickupTime;
  final bool isAccessibilityActive;
  final bool batteryOptGranted;
  final bool overlayGranted;
  final bool notificationsGranted;
  final List<SaudiLocationItem> allLocations;
  final List<String> avoidWords;
  final List<String> likedWords;
  final String serverUrl;
  final String licenseKey;
  final VoidCallback onOpenAccessibilitySettings;
  final VoidCallback onOpenBatterySettings;
  final VoidCallback onOpenOverlaySettings;
  final VoidCallback onOpenNotificationSettings;

  const AdvancedControlScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.runAutoEngine,
    required this.autoRefresh,
    required this.autoReject,
    required this.filterDistance,
    required this.minPrice,
    required this.maxPrice,
    required this.maxPickupTime,
    required this.isAccessibilityActive,
    required this.batteryOptGranted,
    required this.overlayGranted,
    required this.notificationsGranted,
    required this.allLocations,
    required this.avoidWords,
    required this.likedWords,
    required this.serverUrl,
    required this.licenseKey,
    required this.onOpenAccessibilitySettings,
    required this.onOpenBatterySettings,
    required this.onOpenOverlaySettings,
    required this.onOpenNotificationSettings,
  });

  @override
  State<AdvancedControlScreen> createState() => _AdvancedControlScreenState();
}

class _AdvancedControlScreenState extends State<AdvancedControlScreen> with WidgetsBindingObserver {
  late bool runAutoEngine;
  late bool autoRefresh;
  late bool autoReject;
  late bool filterDistance;

  late TextEditingController _minPriceController;
  late TextEditingController _maxPriceController;
  late TextEditingController _maxPickupController;
  final TextEditingController _avoidController = TextEditingController();
  final TextEditingController _likedController = TextEditingController();

  late bool isAccessibilityActive;
  late bool batteryOptGranted;
  late bool overlayGranted;
  late bool notificationsGranted;

  late List<SaudiLocationItem> allLocations;
  late List<String> avoidWords;
  late List<String> likedWords;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    runAutoEngine = widget.runAutoEngine;
    autoRefresh = widget.autoRefresh;
    autoReject = widget.autoReject;
    filterDistance = widget.filterDistance;

    _minPriceController = TextEditingController(text: widget.minPrice);
    _maxPriceController = TextEditingController(text: widget.maxPrice);
    _maxPickupController = TextEditingController(text: widget.maxPickupTime);

    isAccessibilityActive = widget.isAccessibilityActive;
    batteryOptGranted = widget.batteryOptGranted;
    overlayGranted = widget.overlayGranted;
    notificationsGranted = widget.notificationsGranted;

    allLocations = List<SaudiLocationItem>.from(widget.allLocations);
    avoidWords = List<String>.from(widget.avoidWords);
    likedWords = List<String>.from(widget.likedWords);

    _refreshPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _maxPickupController.dispose();
    _avoidController.dispose();
    _likedController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPermissions();
    }
  }

  Future<void> _refreshPermissions() async {
    const platform = MethodChannel('com.drivingcare.saudi/accessibility');
    try {
      final isAcc = await platform.invokeMethod<bool>('isAccessibilityEnabled');
      final isBatt = await platform.invokeMethod<bool>('isBatteryOptExempt');
      final isOver = await platform.invokeMethod<bool>('canDrawOverlays');
      final isNotif = await platform.invokeMethod<bool>('areNotificationsEnabled');
      if (mounted) {
        setState(() {
          isAccessibilityActive = isAcc ?? false;
          batteryOptGranted = isBatt ?? false;
          overlayGranted = isOver ?? false;
          if (isNotif != null) {
            notificationsGranted = isNotif;
          }
        });
      }
    } catch (_) {}
  }

  void _openQuickSelectBlockedLocationsModal() {
    final tempSelections = List<bool>.from(allLocations.map((e) => e.isSelected));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = widget.isDarkMode;
            final dialogBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;

            return Dialog(
              backgroundColor: dialogBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Quick Select Blocked Locations',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 14),

                    // Top 2 Pill Buttons: SELECT ALL & REMOVE ALL
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            onPressed: () {
                              setModalState(() {
                                for (int i = 0; i < tempSelections.length; i++) {
                                  tempSelections[i] = true;
                                }
                              });
                            },
                            child: const Text('SELECT ALL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            onPressed: () {
                              setModalState(() {
                                for (int i = 0; i < tempSelections.length; i++) {
                                  tempSelections[i] = false;
                                }
                              });
                            },
                            child: const Text('REMOVE ALL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // List of Saudi Locations
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: allLocations.length,
                        itemBuilder: (c, idx) {
                          final loc = allLocations[idx];
                          final isChecked = tempSelections[idx];
                          return InkWell(
                            onTap: () {
                              setModalState(() {
                                tempSelections[idx] = !tempSelections[idx];
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: isChecked,
                                    activeColor: const Color(0xFF2563EB),
                                    onChanged: (val) {
                                      setModalState(() {
                                        tempSelections[idx] = val ?? false;
                                      });
                                    },
                                  ),
                                  Expanded(
                                    child: Text(
                                      loc.title,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                                        fontWeight: isChecked ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('CANCEL', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              for (int i = 0; i < allLocations.length; i++) {
                                allLocations[i].isSelected = tempSelections[i];
                              }
                            });
                            Navigator.pop(ctx);
                          },
                          child: const Text('SAVE SELECTION', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _addAvoidWord() {
    final text = _avoidController.text.trim();
    if (text.isNotEmpty && !avoidWords.contains(text)) {
      setState(() {
        avoidWords.add(text);
        _avoidController.clear();
      });
    }
  }

  void _addLikedWord() {
    final text = _likedController.text.trim();
    if (text.isNotEmpty && !likedWords.contains(text)) {
      setState(() {
        likedWords.add(text);
        _likedController.clear();
      });
    }
  }

  Future<void> _applyAndSaveSettings() async {
    final currentSettings = {
      'runAutoEngine': runAutoEngine,
      'autoRefresh': autoRefresh,
      'autoReject': autoReject,
      'filterDistance': filterDistance,
      'minPrice': _minPriceController.text.trim(),
      'maxPrice': _maxPriceController.text.trim(),
      'maxPickupTime': _maxPickupController.text.trim(),
      'blockedLocations': allLocations.where((l) => l.isSelected).map((l) => l.title).toList(),
      'avoidWords': avoidWords,
      'likedWords': likedWords,
    };

    // Sync to laptop backend
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
      final uri = Uri.parse('${widget.serverUrl}/api/settings');
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'key': widget.licenseKey,
        'device': 'Driver Mobile',
        'settings': currentSettings,
      }));
      await request.close();
    } catch (_) {}

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFF10B981),
        content: Text('Settings Applied & Synced to Native Engine! ✔'),
      ),
    );

    Navigator.pop(context, {
      'runAutoEngine': runAutoEngine,
      'autoRefresh': autoRefresh,
      'autoReject': autoReject,
      'filterDistance': filterDistance,
      'minPrice': _minPriceController.text.trim(),
      'maxPrice': _maxPriceController.text.trim(),
      'maxPickupTime': _maxPickupController.text.trim(),
      'avoidWords': avoidWords,
      'likedWords': likedWords,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE5E7EB);
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
    final selectedBlocked = allLocations.where((loc) => loc.isSelected).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Advanced Control',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: 'Toggle Black/White Theme',
            icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Permission Card (sec_101.jpg)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  const Text(
                    'Access permission is required',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildPermissionCard(
                        title: 'Accessibility',
                        icon: Icons.accessibility_new_rounded,
                        isGranted: isAccessibilityActive,
                        onTap: () {
                          widget.onOpenAccessibilitySettings();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Settings khul rahi hai. Driving Care ko Turn ON karein!')),
                          );
                        },
                      ),
                      _buildPermissionCard(
                        title: 'Battery Opt',
                        icon: Icons.battery_charging_full_rounded,
                        isGranted: batteryOptGranted,
                        onTap: () {
                          widget.onOpenBatterySettings();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Battery Optimization Settings khul rahi hain...')),
                          );
                        },
                      ),
                      _buildPermissionCard(
                        title: 'Display Overlay',
                        icon: Icons.layers_rounded,
                        isGranted: overlayGranted,
                        onTap: () {
                          widget.onOpenOverlaySettings();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Display Overlay Settings khul rahi hain...')),
                          );
                        },
                      ),
                      _buildPermissionCard(
                        title: 'Notifications',
                        icon: Icons.notifications_active_rounded,
                        isGranted: notificationsGranted,
                        onTap: () {
                          widget.onOpenNotificationSettings();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Notification Settings khul rahi hain...')),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Color(0xFFD97706)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Samsung / Xiaomi Users: Settings → Apps → Driving Care → Battery → "Unrestricted" select karein aur Device Care "Sleeping apps" se Driving Care ko bahir rakhein taake background mein bot band na ho.',
                            style: TextStyle(fontSize: 11, color: Color(0xFFB45309), height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Automation Toggles (sec_101.jpg)
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  _buildToggleRow(
                    icon: Icons.play_arrow_rounded,
                    iconBg: const Color(0xFF2563EB),
                    title: 'Run Auto Engine',
                    value: runAutoEngine,
                    onChanged: (val) => setState(() => runAutoEngine = val),
                    textPrimary: textPrimary,
                  ),
                  Divider(height: 1, color: borderColor),
                  _buildToggleRow(
                    icon: Icons.refresh_rounded,
                    iconBg: const Color(0xFF2563EB),
                    title: 'Auto Refresh',
                    value: autoRefresh,
                    onChanged: (val) => setState(() => autoRefresh = val),
                    textPrimary: textPrimary,
                  ),
                  Divider(height: 1, color: borderColor),
                  _buildToggleRow(
                    icon: Icons.close_rounded,
                    iconBg: const Color(0xFFEF4444),
                    title: 'Auto Reject',
                    value: autoReject,
                    onChanged: (val) => setState(() => autoReject = val),
                    textPrimary: textPrimary,
                  ),
                  Divider(height: 1, color: borderColor),
                  _buildToggleRow(
                    icon: Icons.location_on_rounded,
                    iconBg: const Color(0xFF2563EB),
                    title: 'Filter Distance',
                    value: filterDistance,
                    onChanged: (val) => setState(() => filterDistance = val),
                    textPrimary: textPrimary,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Target Price Range (sec_101.jpg & sec_141.jpg)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFF22C55E), size: 18),
                      const SizedBox(width: 8),
                      Text('Target Price Range', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Min Price', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              Row(
                                children: [
                                  const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: TextField(
                                      controller: _minPriceController,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 4)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Max Price', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              Row(
                                children: [
                                  const Icon(Icons.keyboard_arrow_up_rounded, size: 18, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: TextField(
                                      controller: _maxPriceController,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 4)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Pickup Limits
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, color: Color(0xFF2563EB), size: 18),
                      const SizedBox(width: 8),
                      Text('Pickup Limits', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Max Pickup Time', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        TextField(
                          controller: _maxPickupController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 4)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Blocked Locations (sec_141.jpg)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.block_rounded, color: Color(0xFFEF4444), size: 18),
                          const SizedBox(width: 8),
                          Text('Blocked Locations', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
                        ],
                      ),
                      InkWell(
                        onTap: _openQuickSelectBlockedLocationsModal,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.format_list_bulleted_rounded, color: Color(0xFF2563EB), size: 20),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  if (selectedBlocked.isNotEmpty) ...[
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: selectedBlocked.length,
                        separatorBuilder: (c, i) => const SizedBox(width: 8),
                        itemBuilder: (c, idx) {
                          final loc = selectedBlocked[idx];
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  loc.title,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () => setState(() => loc.isSelected = false),
                                  child: const Icon(Icons.close_rounded, size: 14, color: Colors.grey),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Avoid Words input
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _avoidController,
                            decoration: const InputDecoration(
                              hintText: 'Avoid Words',
                              hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 10),
                            ),
                            onSubmitted: (_) => _addAvoidWord(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_rounded, color: Colors.grey),
                          onPressed: _addAvoidWord,
                        ),
                      ],
                    ),
                  ),

                  if (avoidWords.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: avoidWords.map((word) {
                        return Chip(
                          backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF1F5F9),
                          label: Text(word, style: const TextStyle(fontSize: 11)),
                          deleteIcon: const Icon(Icons.close, size: 12),
                          onDeleted: () => setState(() => avoidWords.remove(word)),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Preferred Locations
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.favorite_rounded, color: Color(0xFF22C55E), size: 18),
                      const SizedBox(width: 8),
                      Text('Preferred Locations', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _likedController,
                            decoration: const InputDecoration(
                              hintText: 'Liked Words',
                              hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 10),
                            ),
                            onSubmitted: (_) => _addLikedWord(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_rounded, color: Colors.grey),
                          onPressed: _addLikedWord,
                        ),
                      ],
                    ),
                  ),

                  if (likedWords.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: likedWords.map((word) {
                        return Chip(
                          backgroundColor: isDark ? const Color(0xFF1E3A2F) : const Color(0xFFE8F8F0),
                          label: Text(word, style: const TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                          deleteIcon: const Icon(Icons.close, size: 12, color: Color(0xFF10B981)),
                          onDeleted: () => setState(() => likedWords.remove(word)),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Bottom Buttons: BACK and APPLY SETTINGS
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B7280),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('BACK', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('APPLY SETTINGS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    onPressed: _applyAndSaveSettings,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required String title,
    required IconData icon,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isGranted ? const Color(0xFFE8F8F0) : const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: isGranted ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              size: 28,
            ),
          ),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required Color iconBg,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color textPrimary,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 12),
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
            ],
          ),
          Switch(
            value: value,
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF4F46E5),
            inactiveThumbColor: Colors.grey.shade400,
            inactiveTrackColor: Colors.grey.shade300,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
