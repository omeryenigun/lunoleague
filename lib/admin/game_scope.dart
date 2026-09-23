import 'package:flutter/widgets.dart';
import 'package:kelimelig/admin/admin_directory.dart';
import 'package:kelimelig/admin/game_catalog.dart';
import 'package:kelimelig/domain/game/game_server.dart';

/// Active isolated game. Lives above [MaterialApp] so pushed detail routes
/// still read the selected game's server, not another game's data.
class AdminGameScope extends InheritedWidget {
  const AdminGameScope({
    super.key,
    required this.authed,
    required this.directory,
    required this.game,
    required this.server,
    required this.token,
    required this.onAuthed,
    required this.onOpenGame,
    required this.onLeaveGame,
    required this.onSignOut,
    required super.child,
  });

  final bool authed;
  final AdminDirectory directory;
  final String? token;
  final AdminGameDefinition? game;
  final GameServer? server;
  final ValueChanged<String> onAuthed;
  final ValueChanged<String> onOpenGame;
  final VoidCallback onLeaveGame;
  final VoidCallback onSignOut;

  static GameServer serverOf(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AdminGameScope>();
    final server = scope?.server;
    if (server == null) {
      throw StateError('Oyun seçilmeden veri okunamaz.');
    }
    return server;
  }

  static AdminGameDefinition gameOf(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AdminGameScope>();
    final game = scope?.game;
    if (game == null) {
      throw StateError('Oyun seçilmeden panel açılmaz.');
    }
    return game;
  }

  @override
  bool updateShouldNotify(AdminGameScope oldWidget) =>
      oldWidget.authed != authed ||
      oldWidget.token != token ||
      oldWidget.game?.id != game?.id ||
      oldWidget.server != server;
}

GameServer adminServer(BuildContext context) => AdminGameScope.serverOf(context);
