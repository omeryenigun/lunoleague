import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as im;
import 'package:kelimelig/api/site_card_media.dart';

void main() {
  test('image content type accepts png jpeg and webp', () {
    expect(
      imageContentType([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
      'image/png',
    );
    expect(imageContentType([0xFF, 0xD8, 0xFF, 0xE0]), 'image/jpeg');
    expect(
      imageContentType([
        0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, // RIFF
        0x57, 0x45, 0x42, 0x50, // WEBP
      ]),
      'image/webp',
    );
    expect(imageContentType([0x00, 0x01, 0x02]), isNull);
  });

  test('upload becomes a webp sized for its slot', () {
    final wide = im.Image(width: 800, height: 400);
    im.fill(wide, color: im.ColorRgb8(20, 120, 200));
    final png = im.encodePng(wide);

    final icon = prepareWebImage(png, role: siteMediaIcon);
    expect(icon, isNotNull);
    expect(imageContentType(icon!), 'image/webp');
    final iconImage = im.decodeWebP(icon);
    expect(iconImage!.width, 512);
    expect(iconImage.height, 256);

    final shot = prepareWebImage(png, role: siteMediaShot);
    final shotImage = im.decodeWebP(shot!);
    expect(shotImage!.width, 800);
    expect(shotImage.height, 400);
    expect(siteShotLimit, 15);
    expect(webImageMaxEdge(siteMediaShowcase), 1600);
  });
}
