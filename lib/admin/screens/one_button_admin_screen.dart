import 'package:flutter/material.dart';
import 'package:kelimelig/admin/admin_hub.dart';

/// Empty ONE BUTTON admin shell. Hub entry only; no game tooling yet.
class OneButtonAdminScreen extends StatelessWidget {
  const OneButtonAdminScreen({super.key, required this.onLeave});

  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminHubColors.bg,
      body: Column(
        children: [
          ColoredBox(
            color: AdminHubColors.bar,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: onLeave,
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Oyunlar'),
                      style: TextButton.styleFrom(
                        foregroundColor: AdminHubColors.muted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'ONE BUTTON',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Expanded(child: SizedBox.expand()),
        ],
      ),
    );
  }
}
