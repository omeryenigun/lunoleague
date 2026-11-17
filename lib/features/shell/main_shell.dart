import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/core/widgets/app_bottom_nav.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final selected = AppBottomNav.indexForPath(location) ?? 0;
    return Scaffold(
      backgroundColor: AppColors.cosmicBg,
      body: child,
      bottomNavigationBar: AppBottomNav(selectedIndex: selected),
    );
  }
}
