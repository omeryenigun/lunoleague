import 'package:flutter/foundation.dart';
import 'package:kelimelig/domain/entities/cosmetics.dart';
import 'package:kelimelig/domain/entities/user_entity.dart';

class Appearance extends ChangeNotifier {
  String theme = Cosmetics.themeDefault;
  String frame = Cosmetics.frameDefault;

  bool get seasonTheme => theme == Cosmetics.themeSeason;

  void sync(UserEntity? user) {
    theme = user?.equippedTheme ?? Cosmetics.themeDefault;
    frame = user?.equippedFrame ?? Cosmetics.frameDefault;
    notifyListeners();
  }
}
