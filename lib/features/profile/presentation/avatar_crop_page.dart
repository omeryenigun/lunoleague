import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/injection.dart';

/// Square crop. The circle is the frame the profile uses.
class AvatarCropPage extends StatefulWidget {
  const AvatarCropPage({super.key, required this.bytes});

  final Uint8List bytes;

  static Future<Uint8List?> open(BuildContext context, Uint8List bytes) {
    return Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => AvatarCropPage(bytes: bytes)),
    );
  }

  @override
  State<AvatarCropPage> createState() => _AvatarCropPageState();
}

class _AvatarCropPageState extends State<AvatarCropPage> {
  ui.Image? _image;
  var _scale = 1.0;
  var _offset = Offset.zero;
  var _startScale = 1.0;
  var _failed = false;

  static const _view = 280.0;
  static const _out = 256;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  Future<void> _decode() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() => _image = frame.image);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  void _clamp(ui.Image image) {
    final cover = math.max(_view / image.width, _view / image.height);
    final actual = cover * _scale;
    final maxDx = math.max(0.0, (image.width * actual - _view) / 2);
    final maxDy = math.max(0.0, (image.height * actual - _view) / 2);
    _offset = Offset(
      _offset.dx.clamp(-maxDx, maxDx),
      _offset.dy.clamp(-maxDy, maxDy),
    );
  }

  Future<void> _use() async {
    final image = _image;
    if (image == null) return;
    final cover = math.max(_view / image.width, _view / image.height);
    final actual = cover * _scale;
    final dw = image.width * actual;
    final dh = image.height * actual;
    final left = (_view - dw) / 2 + _offset.dx;
    final top = (_view - dh) / 2 + _offset.dy;
    final src = Rect.fromLTWH(-left / actual, -top / actual, _view / actual, _view / actual);
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(
      image,
      src,
      const Rect.fromLTWH(0, 0, 256, 256),
      Paint(),
    );
    final shot = await recorder.endRecording().toImage(_out, _out);
    final data = await shot.toByteData(format: ui.ImageByteFormat.png);
    shot.dispose();
    if (!mounted || data == null) return;
    Navigator.of(context).pop(data.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = sl<L10n>();
    final image = _image;
    return Scaffold(
      backgroundColor: AppColors.cosmicBg,
      appBar: AppBar(
        backgroundColor: AppColors.cosmicBg,
        foregroundColor: const Color(0xFFF8FAFC),
        title: Text(l10n.t('crop_title')),
      ),
      body: Column(
        children: [
          const Spacer(),
          if (_failed)
            const Icon(Icons.broken_image_outlined, color: Color(0xFF94A3B8), size: 48)
          else if (image == null)
            const CircularProgressIndicator(color: AppColors.cosmicGreen)
          else
            GestureDetector(
              onScaleStart: (_) => _startScale = _scale,
              onScaleUpdate: (details) {
                setState(() {
                  _scale = (_startScale * details.scale).clamp(1.0, 4.0);
                  _offset += details.focalPointDelta;
                  _clamp(image);
                });
              },
              child: ClipOval(
                child: SizedBox(
                  width: _view,
                  height: _view,
                  child: CustomPaint(
                    painter: _CropPainter(
                      image: image,
                      scale: _scale,
                      offset: _offset,
                      view: _view,
                    ),
                  ),
                ),
              ),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: image == null ? null : _use,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.cosmicGreen,
                  foregroundColor: const Color(0xFF052E16),
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(l10n.t('crop_use')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CropPainter extends CustomPainter {
  _CropPainter({
    required this.image,
    required this.scale,
    required this.offset,
    required this.view,
  });

  final ui.Image image;
  final double scale;
  final Offset offset;
  final double view;

  @override
  void paint(Canvas canvas, Size size) {
    final cover = math.max(view / image.width, view / image.height);
    final actual = cover * scale;
    final dw = image.width * actual;
    final dh = image.height * actual;
    final dest = Rect.fromLTWH((view - dw) / 2 + offset.dx, (view - dh) / 2 + offset.dy, dw, dh);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      dest,
      Paint(),
    );
  }

  @override
  bool shouldRepaint(covariant _CropPainter oldDelegate) {
    return oldDelegate.scale != scale || oldDelegate.offset != offset || oldDelegate.image != image;
  }
}
