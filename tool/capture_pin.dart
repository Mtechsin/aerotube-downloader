import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

void main() async {
  final client = HttpClient();
  client.badCertificateCallback = (X509Certificate cert, String host, int port) {
    try {
      final spki = _extractSPKI(cert.der);
      if (spki != null) {
        final fp = sha256.convert(spki).toString().toUpperCase();
        stdout.writeln('SPKI pin for $host: $fp');
      } else {
        stdout.writeln('SPKI extraction returned null for $host');
      }
    } catch (e) {
      stdout.writeln('Error: $e');
    }
    return false;
  };

  try {
    final req = await client.getUrl(Uri.parse('https://api.github.com/'));
    final res = await req.close();
    await res.drain<void>();
  } catch (e) {
    // Expected
  }
  client.close(force: true);
}

Uint8List? _extractSPKI(Uint8List der) {
  int offset = 0;

  _DerTlv read() {
    final tag = der[offset++];
    var lenByte = der[offset++];
    int len;
    if ((lenByte & 0x80) == 0) {
      len = lenByte;
    } else {
      final n = lenByte & 0x7F;
      len = 0;
      for (var i = 0; i < n; i++) {
        len = (len << 8) | der[offset++];
      }
    }
    final start = offset;
    offset += len;
    return _DerTlv(tag, Uint8List.sublistView(der, start, offset));
  }

  try {
    final outer = read();
    if (outer.tag != 0x30) return null;
    final tbs = read();
    if (tbs.tag != 0x30) return null;
    var field = read();
    if (field.tag == 0xA0) {
      field = read();
    }
    for (var i = 0; i < 5; i++) {
      read();
    }
    final spki = read();
    if (spki.tag != 0x30) return null;
    return spki.fullEncoding;
  } catch (_) {
    return null;
  }
}

class _DerTlv {
  final int tag;
  final Uint8List content;
  _DerTlv(this.tag, this.content);
  Uint8List get fullEncoding => content;
}
