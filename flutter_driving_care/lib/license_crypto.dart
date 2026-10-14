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
  // Master Ed25519 Public Key for offline signature verification (Pure Single Truth)
  // Rotated Fresh Key (No legacy keys trusted)
  static const String masterPublicKeyHex =
      'd63f4fcdd57a0c44e3084f0c4cdd74d83864f3f2f1bf3c7c070c561df779627e';

  static final _algorithm = Ed25519();

  static List<int> _hexToBytes(String hex) {
    hex = hex.replaceAll(' ', '').trim();
    final bytes = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  /// Verifies any license key offline (even in Airplane Mode).
  /// ONLY cryptographically signed keys: "DCS-<payload>.<sig>" are allowed.
  /// No plain keys, no bypass lists, no legacy keys.
  static Future<LicenseInfo> verifyOfflineKey(String inputKey) async {
    final cleanKey = inputKey.trim();
    if (cleanKey.isEmpty) {
      return LicenseInfo(
        isValid: false,
        key: '',
        driverName: '',
        daysLeft: 0,
        errorMessage: 'Barah-e-karam License Key darj karein.',
      );
    }

    final isSigned = cleanKey.startsWith('DCS-') || (cleanKey.contains('.') && cleanKey.length > 50);
    if (!isSigned) {
      return LicenseInfo(
        isValid: false,
        key: cleanKey,
        driverName: '',
        daysLeft: 0,
        errorMessage: 'Purani plain keys band hain. Sirf DCS signed keys se activation hogi.',
      );
    }

    try {
      final keyBody = cleanKey.startsWith('DCS-') ? cleanKey.substring(4) : cleanKey;
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

        // Verify Ed25519 signature strictly against the rotated master public key
        bool isSignatureValid = false;
        try {
          final pubBytes = _hexToBytes(masterPublicKeyHex);
          final publicKey = SimplePublicKey(pubBytes, type: KeyPairType.ed25519);
          final signature = Signature(sigBytes, publicKey: publicKey);
          isSignatureValid = await _algorithm.verify(
            utf8.encode(payloadB64),
            signature: signature,
          );
        } catch (_) {
          isSignatureValid = false;
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
        key: cleanKey,
        driverName: '',
        daysLeft: 0,
        errorMessage: 'Key format durust nahi hai ($e).',
      );
    }

    return LicenseInfo(
      isValid: false,
      key: cleanKey,
      driverName: '',
      daysLeft: 0,
      errorMessage: 'Invalid License Key! Developer Ikram se rabta karein.',
    );
  }
}
