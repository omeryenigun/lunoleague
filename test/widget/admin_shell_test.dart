import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kelimelig/admin/admin_app.dart';
import 'package:kelimelig/admin/admin_directory.dart';
import 'package:kelimelig/core/constants/game_version.dart';
import 'package:kelimelig/core/services/audio_manager.dart';
import 'package:kelimelig/core/services/haptic_manager.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/injection.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    await sl.reset();
    await configureDependencies(store: MemoryKeyValueStore(), initHive: false);
    sl<AudioManager>().enabled = false;
    sl<HapticManager>().enabled = false;
    sl.registerSingleton<AdminDirectory>(
      MemoryAdminDirectory.seeded(
        email: 'admin@example.com',
        password: 'admin-pass-12',
      ),
    );
  });

  testWidgets('shared admin opens one isolated game', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const AdminApp());
    await tester.pump();
    await tester.pump();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'admin@example.com');
    await tester.enterText(fields.at(1), 'admin-pass-12');
    await tester.tap(find.text('Giriş'));
    await tester.pumpAndSettle();

    expect(find.text('Luno Ekosistemi'), findsOneWidget);
    expect(find.text(GameVersion.parse(gameVersionCode).label), findsWidgets);
    expect(find.text('Luno League'), findsOneWidget);
    expect(find.textContaining('luno_league'), findsWidgets);
    expect(find.text('Yöneticiler'), findsWidgets);
    expect(find.text('Kelimeler'), findsNothing);

    await tester.tap(find.text('Yönet').first);
    await tester.pumpAndSettle();

    expect(find.text('Özet'), findsWidgets);
    expect(find.text('Daily'), findsWidgets);
    expect(find.text('Yöneticiler'), findsWidgets);

    await tester.tap(find.byTooltip('Oyunlara dön'));
    await tester.pumpAndSettle();

    expect(find.text('İzole depo:'), findsWidgets);
    expect(find.textContaining('luno_league'), findsWidgets);
  });
}
