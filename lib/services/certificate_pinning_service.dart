import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

class CertificatePinningService {
  static final CertificatePinningService _instance = CertificatePinningService._internal();
  factory CertificatePinningService() => _instance;
  CertificatePinningService._internal();

  static const Map<String, List<String>> _pinnedCertificates = {
    'api.github.com': [
      'B3A5B6E7A1E8F9C2D4E5F6A7B8C9D0E1F2A3B4C5D6E7F8A9B0C1D2E3F4A5B6',
    ],
  };

  static const Duration _cacheDuration = Duration(hours: 24);
  final Map<String, DateTime> _lastVerified = {};

  bool isCertificateValid(String host, X509Certificate certificate) {
    if (!_pinnedCertificates.containsKey(host)) {
      return true;
    }

    final pinnedFingerprints = _pinnedCertificates[host]!;
    final certificateFingerprint = _getCertificateFingerprint(certificate);

    return pinnedFingerprints.contains(certificateFingerprint);
  }

  String _getCertificateFingerprint(X509Certificate certificate) {
    final bytes = certificate.der;
    final digest = sha256.convert(bytes);
    return digest.toString().toUpperCase();
  }

  HttpClient createPinnedHttpClient() {
    final client = HttpClient();
    
    client.badCertificateCallback = (X509Certificate certificate, String host, int port) {
      if (kDebugMode) {
        debugPrint('Certificate pinning: Validating certificate for $host');
      }

      if (!_pinnedCertificates.containsKey(host)) {
        if (kDebugMode) {
          debugPrint('Certificate pinning: No pins for $host, allowing connection');
        }
        return false;
      }

      final isValid = isCertificateValid(host, certificate);
      
      if (!isValid) {
        debugPrint('Certificate pinning: INVALID certificate for $host');
      } else {
        if (kDebugMode) {
          debugPrint('Certificate pinning: Valid certificate for $host');
        }
        _lastVerified[host] = DateTime.now();
      }

      return !isValid;
    };

    return client;
  }

  bool isRecentlyVerified(String host) {
    if (!_lastVerified.containsKey(host)) return false;
    
    final lastVerified = _lastVerified[host]!;
    final now = DateTime.now();
    
    return now.difference(lastVerified) < _cacheDuration;
  }

  void clearCache() {
    _lastVerified.clear();
  }

  void addPin(String host, String fingerprint) {
    if (_pinnedCertificates.containsKey(host)) {
      _pinnedCertificates[host]!.add(fingerprint);
    } else {
      _pinnedCertificates[host] = [fingerprint];
    }
  }

  void removePin(String host, String fingerprint) {
    if (_pinnedCertificates.containsKey(host)) {
      _pinnedCertificates[host]!.remove(fingerprint);
      if (_pinnedCertificates[host]!.isEmpty) {
        _pinnedCertificates.remove(host);
      }
    }
  }

  Map<String, List<String>> get pinnedCertificates => Map.unmodifiable(_pinnedCertificates);
}