import 'dart:convert';
import 'package:cryptography/cryptography.dart';

class LicenseInfo {
  final bool isValid;
  final String key;
  final String driverName;
  final int daysLeft;
  final String errorMessage;
  final bool isOfflineSigned;

  LicenseInfo({
    required this.isValid,
    required this.key,
    required this.driverName,
    required this.daysLeft,
    this.errorMessage = '',
    this.isOfflineSigned = false,
  });
}

class DrivingCareCrypto {
  // Master Ed25519 Public Keys for offline signature verification (Safe in client code)
  // Dual public key verification: Supports rotated new master key + legacy key for already issued drivers
  static const List<String> trustedPublicKeysHex = [
    'ca9aff6928e1b296b24d83589758128c5b6be2c1a555f1da3dfa72f1c3f63937', // Rotated New Master Key
    '4d33b73ef90afd009626442d74ce1d593cd6db64f1d23b83d1ecbcb33a9588e9', // Legacy Master Key (Transition)
  ];
  static const String masterPublicKeyHex =
      'ca9aff6928e1b296b24d83589758128c5b6be2c1a555f1da3dfa72f1c3f63937';

  static final _algorithm = Ed25519();

  // Pre-authorized legacy/VIP offline whitelist keys (Zero server reliance)
  static final Map<String, Map<String, dynamic>> legacyOfflineKeys = {
    'DC-NASIR-11': {'name': 'Nasir', 'days': 30},
    'DC-NASIR-1111': {'name': 'Nasir', 'days': 30},
    'DC-7300': {'name': 'Nasir-hussain', 'days': 30},
    'DC-8921': {'name': 'Tariq Al-Harbi', 'days': 30},
    'IKRAM-VIP': {'name': 'Ikram Master Admin', 'days': 365},
    'BILAL-VIP': {'name': 'Bilal (Owner Admin)', 'days': 365},
    'ADNAN-VIP': {'name': 'Adnan (Driver)', 'days': 30},
  };

  static List<int> _hexToBytes(String hex) {
    hex = hex.replaceAll(' ', '').trim();
    final bytes = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  /// Verifies any license key offline (even in Airplane Mode).
  /// 1. Cryptographically signed keys: "DCS-<payload>.<sig>"
  /// 2. Whitelisted legacy driver keys
  static Future<LicenseInfo> verifyOfflineKey(String inputKey) async {
    final cleanKey = inputKey.trim().toUpperCase();
    if (cleanKey.isEmpty) {
      return LicenseInfo(
        isValid: false,
        key: '',
        driverName: '',
        daysLeft: 0,
        errorMessage: 'Barah-e-karam License Key darj karein.',
      );
    }

    // 1. Check Whitelisted Offline Keys first
    for (final entry in legacyOfflineKeys.entries) {
      final k = entry.key.toUpperCase();
      final normK = k.replaceAll(RegExp(r'[^A-Z0-9]'), '');
      final normInput = cleanKey.replaceAll(RegExp(r'[^A-Z0-9]'), '');
      if (cleanKey == k || normInput == normK || normInput == 'DC$normK' || normK == 'DC$normInput') {
        return LicenseInfo(
          isValid: true,
          key: entry.key,
          driverName: entry.value['name'] as String,
          daysLeft: entry.value['days'] as int,
          isOfflineSigned: true,
        );
      }
    }

    // 2. Check Ed25519 Cryptographically Signed Key: "DCS-<payload>.<sig>"
    final isSigned = inputKey.startsWith('DCS-') || (inputKey.contains('.') && inputKey.length > 50);
    if (isSigned) {
      try {
        final keyBody = inputKey.startsWith('DCS-') ? inputKey.substring(4) : inputKey;
        final dotIdx = keyBody.indexOf('.');
        if (dotIdx > 0) {
          final payloadB64 = keyBody.substring(0, dotIdx);
          final sigB64 = keyBody.substring(dotIdx + 1);

          String normalizeB64(String s) {
            var padded = s.replaceAll('-', '+').replaceAll('_', '/');
            while (padded.length % 4 != 0) {
              padded += '=';
            }
            return padded;
          }

          final payloadBytes = base64.decode(normalizeB64(payloadB64));
          final sigBytes = base64.decode(normalizeB64(sigB64));

          final payloadStr = utf8.decode(payloadBytes);
          final payloadJson = jsonDecode(payloadStr) as Map<String, dynamic>;

          final keyId = payloadJson['key']?.toString() ?? 'DC-OFFLINE';
          final name = payloadJson['name']?.toString() ?? 'Authorized Driver';
          final expMs = payloadJson['exp'] is int ? payloadJson['exp'] as int : 0;
          final days = payloadJson['days'] is int ? payloadJson['days'] as int : 30;

          // Verify Ed25519 signature (dual verification: new key + transition legacy key)
          bool isSignatureValid = false;
          for (final pubHex in trustedPublicKeysHex) {
            try {
              final pubBytes = _hexToBytes(pubHex);
              final publicKey = SimplePublicKey(pubBytes, type: KeyPairType.ed25519);
              final signature = Signature(sigBytes, publicKey: publicKey);
              final valid = await _algorithm.verify(
                utf8.encode(payloadB64),
                signature: signature,
              );
              if (valid) {
                isSignatureValid = true;
                break;
              }
            } catch (_) {}
          }

          if (!isSignatureValid) {
            return LicenseInfo(
              isValid: false,
              key: keyId,
              driverName: '',
              daysLeft: 0,
              errorMessage: 'Ghalat Key Signature! Key ke sath chher-chhaar hui hai.',
            );
          }

          // Check Expiry Date
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          if (expMs > 0 && nowMs > expMs) {
            return LicenseInfo(
              isValid: false,
              key: keyId,
              driverName: name,
              daysLeft: 0,
              errorMessage: 'Aapki License Key expire ho chuki hai.',
            );
          }

          final remainingDays = expMs > 0 ? ((expMs - nowMs) / (86400 * 1000)).ceil() : days;

          return LicenseInfo(
            isValid: true,
            key: keyId,
            driverName: name,
            daysLeft: remainingDays > 0 ? remainingDays : days,
            isOfflineSigned: true,
          );
        }
      } catch (e) {
        return LicenseInfo(
          isValid: false,
          key: inputKey,
          driverName: '',
          daysLeft: 0,
          errorMessage: 'Key format durust nahi hai ($e).',
        );
      }
    }

    return LicenseInfo(
      isValid: false,
      key: inputKey,
      driverName: '',
      daysLeft: 0,
      errorMessage: 'Invalid License Key! Developer Ikram se rabta karein.',
    );
  }
}
