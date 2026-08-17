import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Certificate pinning service.
///
/// Pins are [SPKI (SubjectPublicKeyInfo)] SHA-256 fingerprints rather than
/// full-certificate hashes, so they survive routine certificate renewals
/// (only a CA / key rotation invalidates them — the standard "pin a backup
/// key too" mitigation is supported by keeping multiple pins per host).
///
/// IMPORTANT (fail-closed): the pinned [HttpClient] returned by
/// [createPinnedHttpClient] only permits hosts that have at least one pin
/// registered AND whose presented certificate matches a pinned fingerprint.
/// Any other host is rejected. Callers that need to reach a new host must
/// first add a pin for it (typically via [capturePinForHost] during
/// development).
class CertificatePinningService {
  static final CertificatePinningService _instance =
      CertificatePinningService._internal();
  factory CertificatePinningService() => _instance;
  CertificatePinningService._internal();

  /// Pinned SPKI SHA-256 fingerprints per host (uppercase hex, no separators).
  ///
  /// NOTE: This MUST be a mutable backing store so that [addPin]/[removePin]
  /// work at runtime. (Previously this was `static const`, which made any
  /// runtime mutation throw — silently disabling all dynamic pin updates.)
  ///
  /// To add pins for a host, run [capturePinForHost] in a debug build:
  /// ```dart
  /// await CertificatePinningService().capturePinForHost('api.github.com');
  /// ```
  static final Map<String, List<String>> _pinnedCertificates = {};

  static const Duration _cacheDuration = Duration(hours: 24);
  final Map<String, DateTime> _lastVerified = {};

  /// Returns true only when [host] has at least one pin registered and the
  /// certificate's SPKI fingerprint matches one of them.
  ///
  /// Fail-closed: a host with no registered pins is treated as invalid so the
  /// pinned client cannot silently bypass pinning for arbitrary hosts.
  bool isCertificateValid(String host, X509Certificate certificate) {
    final pins = _pinnedCertificates[host];
    if (pins == null || pins.isEmpty) {
      return false;
    }
    final spki = _extractSubjectPublicKeyInfo(certificate.der);
    if (spki == null) {
      return false;
    }
    final fingerprint = sha256.convert(spki).toString().toUpperCase();
    return pins.contains(fingerprint);
  }

  /// Computes the SPKI SHA-256 fingerprint (uppercase hex) for [certificate].
  /// Returns null if the DER cannot be parsed.
  String? fingerprintFor(X509Certificate certificate) {
    final spki = _extractSubjectPublicKeyInfo(certificate.der);
    if (spki == null) return null;
    return sha256.convert(spki).toString().toUpperCase();
  }

  /// Returns an [HttpClient] that validates certificate pins via
  /// [badCertificateCallback].
  ///
  /// LIMITATION (Dart platform): `badCertificateCallback` is only invoked
  /// when the OS-level TLS stack rejects the certificate chain (e.g. untrusted
  /// CA, hostname mismatch). Certificates signed by a trusted root CA bypass
  /// this callback entirely, meaning a MITM attacker who obtains a valid
  /// certificate from any trusted CA would not be caught by this check.
  ///
  /// For full protection on mobile, consider using a platform channel to a
  /// native pinning library (e.g. trustkit on iOS, network-security-config
  /// on Android). For desktop, a proxy-based approach or native TLS pinning
  /// is needed.
  HttpClient createPinnedHttpClient() {
    final client = HttpClient();

    client.badCertificateCallback =
        (X509Certificate certificate, String host, int port) {
      final isValid = isCertificateValid(host, certificate);

      if (isValid) {
        if (kDebugMode) {
          debugPrint('Certificate pinning: valid pin match for $host');
        }
        _lastVerified[host] = DateTime.now();
      } else {
        debugPrint(
          'Certificate pinning: REJECTED connection to $host '
          '(no matching pin).',
        );
      }

      // badCertificateCallback: returning true ACCEPTS the bad cert,
      // returning false REJECTS it. Accept only when the pin matches.
      return isValid;
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
    _pinnedCertificates.putIfAbsent(host, () => []).add(fingerprint);
  }

  void removePin(String host, String fingerprint) {
    final pins = _pinnedCertificates[host];
    if (pins == null) return;
    pins.remove(fingerprint);
    if (pins.isEmpty) {
      _pinnedCertificates.remove(host);
    }
  }

  Map<String, List<String>> get pinnedCertificates =>
      Map.unmodifiable(_pinnedCertificates);

  /// Debug-only helper that connects to [host] (bypassing the pin set),
  /// extracts the server certificate's SPKI, and logs the SHA-256 fingerprint
  /// you should paste into [_pinnedCertificates].
  ///
  /// Run this once in a debug build, e.g. from `main.dart` during development:
  ///
  /// ```dart
  /// await CertificatePinningService().capturePinForHost('api.github.com');
  /// ```
  Future<void> capturePinForHost(String host) async {
    if (!kDebugMode) {
      debugPrint('capturePinForHost is only available in debug builds.');
      return;
    }
    final client = HttpClient()
      // Bypass pinning for the capture so we can read the real cert.
      ..badCertificateCallback = (cert, h, p) => false;
    try {
      final request = await client.getUrl(Uri.https(host, '/'));
      final response = await request.close();
      // Drain the body so the socket can close cleanly.
      await response.drain<void>();
      final cert = response.certificate;
      if (cert == null) {
        debugPrint('capturePinForHost: no certificate presented for $host');
        return;
      }
      final fingerprint = fingerprintFor(cert);
      if (fingerprint == null) {
        debugPrint('capturePinForHost: SPKI extraction failed for $host');
        return;
      }
      debugPrint('============ CERT PIN ($host) ============');
      debugPrint(fingerprint);
      debugPrint(
        "Add to _pinnedCertificates: '$host': ['$fingerprint'],",
      );
      debugPrint('=========================================');
    } catch (e) {
      debugPrint('capturePinForHost($host) failed: $e');
    } finally {
      client.close(force: true);
    }
  }

  /// Extracts the DER-encoded SubjectPublicKeyInfo (including its outer
  /// SEQUENCE tag + length) from a DER-encoded X.509 certificate.
  ///
  /// The returned bytes are what standard SPKI pin hashes (Chrome, Mozilla,
  /// HPKP) are computed over. Returns null if the structure cannot be parsed.
  static Uint8List? _extractSubjectPublicKeyInfo(Uint8List der) {
    try {
      final outer = _DerReader(der).read();
      if (outer.tag != 0x30) return null; // Certificate SEQUENCE

      // tbsCertificate is the first child of the outer SEQUENCE.
      final tbs = _DerReader(outer.content).read();
      if (tbs.tag != 0x30) return null;

      final fields = _DerReader(tbs.content);
      var field = fields.read();

      // Optional explicit version [0] tag (0xA0). Skip if present.
      if (field.tag == 0xA0) {
        field = fields.read(); // serialNumber
      }
      // Skip: serialNumber, signatureAlgorithm, issuer, validity, subject.
      for (var i = 0; i < 5; i++) {
        fields.read();
      }
      // Next element is the SubjectPublicKeyInfo SEQUENCE.
      final spki = fields.read();
      if (spki.tag != 0x30) return null;
      return spki.fullEncoding;
    } catch (_) {
      return null;
    }
  }
}

/// Minimal DER (Definite-Length) TLV reader used only for SPKI extraction.
class _DerReader {
  _DerReader(this.bytes);

  final Uint8List bytes;
  int offset = 0;

  bool get hasMore => offset < bytes.length;

  _DerTlv read() {
    if (offset >= bytes.length) {
      throw StateError('Unexpected end of DER input');
    }
    final start = offset;
    final tag = bytes[offset++];
    if (offset >= bytes.length) {
      throw StateError('Truncated DER length');
    }
    var lengthByte = bytes[offset++];
    int length;
    if ((lengthByte & 0x80) == 0) {
      // Short form.
      length = lengthByte;
    } else {
      // Long form: low 7 bits give the number of subsequent length octets.
      final numOctets = lengthByte & 0x7F;
      if (numOctets == 0 || numOctets > 4) {
        throw StateError('Unsupported DER length encoding');
      }
      length = 0;
      for (var i = 0; i < numOctets; i++) {
        length = (length << 8) | bytes[offset++];
      }
    }
    final contentEnd = offset + length;
    if (contentEnd > bytes.length) {
      throw StateError('DER length exceeds available bytes');
    }
    final content =
        Uint8List.sublistView(bytes, offset, contentEnd);
    final full = Uint8List.sublistView(bytes, start, contentEnd);
    offset = contentEnd;
    return _DerTlv(tag, content, full);
  }
}

class _DerTlv {
  const _DerTlv(this.tag, this.content, this.fullEncoding);

  final int tag; // 0x30 = SEQUENCE, 0xA0 = context [0], etc.
  final Uint8List content; // value bytes only
  final Uint8List fullEncoding; // tag + length + value
}
