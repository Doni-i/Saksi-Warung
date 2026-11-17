import 'dart:io';
import 'dart:typed_data';

void main() {
  final targets = <String, int>{
    'assets/icon/app_icon.png': 512,
    'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
    'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
  };

  for (final entry in targets.entries) {
    final file = File(entry.key);
    if (entry.key.startsWith('android/') && !Directory('android/app/src/main/res').existsSync()) {
      continue;
    }
    file.parent.createSync(recursive: true);
    final pngBytes = _renderSaksiWarungPng(entry.value, entry.value);
    file.writeAsBytesSync(pngBytes, flush: true);
    stdout.writeln('Generated ${entry.key} (${entry.value}x${entry.value})');
  }
}

Uint8List _renderSaksiWarungPng(int width, int height) {
  final rgba = Uint8List(width * height * 4);

  void setPixel(int x, int y, int r, int g, int b, int a) {
    if (x < 0 || x >= width || y < 0 || y >= height) return;
    final idx = (y * width + x) * 4;
    rgba[idx] = r;
    rgba[idx + 1] = g;
    rgba[idx + 2] = b;
    rgba[idx + 3] = a;
  }

  for (int y = 0; y < height; y++) {
    final ny = y / height;
    for (int x = 0; x < width; x++) {
      final nx = x / width;

      // Obsidian background (#0F172A)
      int r = 0x0F, g = 0x17, b = 0x2A;

      // Safety-orange border frame (#EA580C)
      final inBorder = (nx >= 0.05 && nx <= 0.95 && ny >= 0.05 && ny <= 0.95) &&
          !(nx >= 0.12 && nx <= 0.88 && ny >= 0.12 && ny <= 0.88);
      if (inBorder) {
        r = 0xEA;
        g = 0x58;
        b = 0x0C;
      }

      // Stall roof trapezoid (#EA580C)
      if (ny >= 0.22 && ny <= 0.36) {
        final t = (ny - 0.22) / 0.14;
        final left = 0.30 - (0.08 * t);
        final right = 0.70 + (0.08 * t);
        if (nx >= left && nx <= right) {
          r = 0xEA;
          g = 0x58;
          b = 0x0C;
        }
      }

      // Left & right white ledger/scale bars (#F8FAFC)
      final inLeftBar = nx >= 0.26 && nx <= 0.37 && ny >= 0.44 && ny <= 0.76;
      final inRightBar = nx >= 0.63 && nx <= 0.74 && ny >= 0.44 && ny <= 0.76;
      if (inLeftBar || inRightBar) {
        r = 0xF8;
        g = 0xFA;
        b = 0xFC;
      }

      // Center orange witness pillar (#EA580C)
      final inCenterBar = nx >= 0.445 && nx <= 0.555 && ny >= 0.40 && ny <= 0.76;
      if (inCenterBar) {
        r = 0xEA;
        g = 0x58;
        b = 0x0C;
      }

      setPixel(x, y, r, g, b, 255);
    }
  }

  final rawScanlines = BytesBuilder(copy: false);
  for (int y = 0; y < height; y++) {
    rawScanlines.addByte(0); // filter type 0 (None)
    final rowStart = y * width * 4;
    rawScanlines.add(rgba.sublist(rowStart, rowStart + width * 4));
  }

  final compressed = ZLibEncoder().convert(rawScanlines.takeBytes());

  final ihdr = BytesBuilder()
    ..add(_uint32Be(width))
    ..add(_uint32Be(height))
    ..addByte(8) // bit depth
    ..addByte(6) // color type RGBA
    ..addByte(0) // compression
    ..addByte(0) // filter
    ..addByte(0); // interlace

  final out = BytesBuilder()
    ..add(const [137, 80, 78, 71, 13, 10, 26, 10])
    ..add(_pngChunk('IHDR', ihdr.takeBytes()))
    ..add(_pngChunk('IDAT', compressed))
    ..add(_pngChunk('IEND', const []));

  return out.takeBytes();
}

Uint8List _pngChunk(String type, List<int> data) {
  final typeBytes = type.codeUnits;
  final crcInput = Uint8List(typeBytes.length + data.length)
    ..setRange(0, typeBytes.length, typeBytes)
    ..setRange(typeBytes.length, typeBytes.length + data.length, data);

  final chunk = BytesBuilder()
    ..add(_uint32Be(data.length))
    ..add(typeBytes)
    ..add(data)
    ..add(_uint32Be(_crc32(crcInput)));
  return chunk.takeBytes();
}

Uint8List _uint32Be(int value) => Uint8List.fromList([
  (value >> 24) & 0xFF,
  (value >> 16) & 0xFF,
  (value >> 8) & 0xFF,
  value & 0xFF,
]);

final List<int> _crcTable = List<int>.generate(256, (n) {
  int c = n;
  for (int k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
  }
  return c;
});

int _crc32(List<int> bytes) {
  int c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >>> 8);
  }
  return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}