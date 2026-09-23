import 'package:flutter/widgets.dart';

class GameLogo extends StatelessWidget {
  const GameLogo({super.key, this.size = 160});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
