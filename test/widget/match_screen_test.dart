import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/domain/game/game_server.dart';
import 'package:kelimelig/features/home/presentation/home_screen.dart';
import 'package:kelimelig/features/match/presentation/duel_screen.dart';
import 'package:kelimelig/features/match/presentation/room_screen.dart';
import 'package:kelimelig/injection.dart';

void main() {
  setUp(() async {
    await sl.reset();
    await configureDependencies(store: MemoryKeyValueStore(), initHive: false);
  });

  testWidgets('duel and room cards and screens fit 320px', (tester) async {
    await sl<GameServer>().signInAnonymously();
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.scrollUntilVisible(find.text('DÜELLO'), 200);
    expect(find.text('DÜELLO'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('ÖZEL ODA'), 200);
    expect(find.text('ÖZEL ODA'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: DuelScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Düello'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));

    await tester.pumpWidget(const MaterialApp(home: RoomScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Özel Oda'), findsOneWidget);
    expect(find.text('ODA OLUŞTUR'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });
}
