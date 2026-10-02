import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_avatars.dart';

void main() {
  test('avatar catalog is 48 unique emojis in four groups of 12', () {
    expect(bilgiAvatarGroups.map((group) => group.label), ['Kadın', 'Erkek', 'Kahraman', 'Hayvan']);
    final all = <String>[];
    for (final group in bilgiAvatarGroups) {
      expect(group.emojis, hasLength(bilgiAvatarGroupSize));
      expect(group.emojis.toSet(), hasLength(bilgiAvatarGroupSize));
      all.addAll(group.emojis);
    }
    expect(all, hasLength(48));
    expect(all.toSet(), hasLength(48));

    const tones = ['\u{1F3FB}', '\u{1F3FC}', '\u{1F3FD}', '\u{1F3FE}', '\u{1F3FF}'];
    for (final emoji in all) {
      for (final tone in tones) {
        expect(emoji.contains(tone), isFalse, reason: emoji);
      }
    }
  });

  test('hayvan reuses the league seed animals', () {
    const seedAnimals = ['🦊', '🐼', '🦁', '🐯', '🐸', '🐙', '🦄', '🐻', '🐨'];
    final animals = bilgiAvatarGroups.singleWhere((group) => group.label == 'Hayvan').emojis;
    for (final animal in seedAnimals) {
      expect(animals, contains(animal));
    }
  });
}
