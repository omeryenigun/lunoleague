import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/features/profile/presentation/avatar_crop_page.dart';
import 'package:kelimelig/injection.dart';

final _picker = ImagePicker();

/// Gallery or camera, then a square crop. Returns a PNG as base64.
Future<String?> pickAvatarBase64(BuildContext context) async {
  final l10n = sl<L10n>();
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: const Color(0xFF0F172A),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(l10n.t('take_photo')),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(l10n.t('choose_photo')),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return null;
  final file = await _picker.pickImage(
    source: source,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 85,
  );
  if (file == null || !context.mounted) return null;
  final bytes = await file.readAsBytes();
  if (!context.mounted) return null;
  final cropped = await AvatarCropPage.open(context, bytes);
  if (cropped == null) return null;
  return base64Encode(cropped);
}

Uint8List? avatarBytes(String? avatar) {
  if (avatar == null || avatar.isEmpty) return null;
  try {
    return base64Decode(avatar);
  } catch (_) {
    return null;
  }
}
