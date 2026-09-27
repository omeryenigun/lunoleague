import 'dart:typed_data';

import 'package:image/image.dart' as im;

const siteMediaMaxBytes = 1572864;
const siteMediaUploadMaxBytes = 8 * 1024 * 1024;
const siteShotLimit = 15;

const siteMediaIcon = 'icon';
const siteMediaShowcase = 'showcase';
const siteMediaShot = 'shot';

/// png, jpeg, or webp. Anything else is refused.
String? imageContentType(List<int> bytes) {
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return 'image/png';
  }
  if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
    return 'image/jpeg';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'image/webp';
  }
  return null;
}

int webImageMaxEdge(String role) {
  return switch (role) {
    siteMediaIcon => 512,
    siteMediaShowcase => 1600,
    _ => 1280,
  };
}

/// Decodes a png, jpeg, or webp and stores a lossy WebP sized for the web.
Uint8List? prepareWebImage(List<int> bytes, {required String role}) {
  if (imageContentType(bytes) == null) return null;
  final decoded = im.decodeImage(Uint8List.fromList(bytes));
  if (decoded == null || decoded.width < 1 || decoded.height < 1) return null;
  if (decoded.width * decoded.height > 24000000) return null;
  final fitted = _fit(decoded, webImageMaxEdge(role));
  final encoded = im.encodeWebP(
    fitted,
    lossless: false,
    quality: 75,
    method: 4,
    exact: false,
  );
  if (encoded.isEmpty) return null;
  return encoded;
}

im.Image _fit(im.Image source, int maxEdge) {
  final longest = source.width > source.height ? source.width : source.height;
  if (longest <= maxEdge) return source;
  if (source.width >= source.height) {
    return im.copyResize(source, width: maxEdge);
  }
  return im.copyResize(source, height: maxEdge);
}
