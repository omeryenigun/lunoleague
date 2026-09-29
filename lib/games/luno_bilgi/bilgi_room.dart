import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';

class BilgiRoomSync {
  const BilgiRoomSync({this.room, this.questions = const [], this.spare, this.message});

  final BilgiRoom? room;
  final List<BilgiQuestion> questions;
  final BilgiQuestion? spare;
  final String? message;

  bool get ok => message == null && room != null;
}

class BilgiRoomHooks {
  const BilgiRoomHooks({
    required this.create,
    required this.join,
    required this.poll,
    required this.start,
    required this.score,
    required this.openGroup,
  });

  final Future<BilgiRoomSync> Function({
    required String kind,
    required String playerId,
    required String name,
    required String categoryId,
    required String subcategory,
    required String difficulty,
  }) create;

  final Future<BilgiRoomSync> Function({
    required String code,
    required String playerId,
    required String name,
  }) join;

  final Future<BilgiRoomSync> Function(String code) poll;

  final Future<BilgiRoomSync> Function({
    required String code,
    required String playerId,
  }) start;

  final Future<bool> Function({
    required String code,
    required String playerId,
    required int score,
    required int index,
  }) score;

  final Future<BilgiRoomSync> Function() openGroup;
}
