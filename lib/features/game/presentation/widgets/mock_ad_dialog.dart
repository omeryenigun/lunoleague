import 'package:flutter/material.dart';
import 'package:kelimelig/core/theme/colors.dart';

Future<bool> showMockRewardedAd(
  BuildContext context, {
  required String title,
  required String message,
  bool canDecline = true,
  String confirmLabel = 'İzledim',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.ondemand_video, size: 48, color: AppColors.warning),
          const SizedBox(height: 12),
          Text(message),
          const SizedBox(height: 8),
          const Text(
            'Reklam henüz önizleme (gerçek SDK yok).',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
      actions: [
        if (canDecline)
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok == true;
}
