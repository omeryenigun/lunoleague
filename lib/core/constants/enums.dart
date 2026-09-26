enum GameType { daily, endless, duel, room }

enum RankPeriod { week, month, season, year }

enum GameStatus { active, won, lost, expired, completed }

enum DailyStatus { available, started, completed }

enum LetterStatus { correct, present, absent, empty }

enum LeagueTier { bronze, silver, gold }

enum HintLevel { letter, meaning }

enum WordStatus { draft, review, approved, active }

enum AuthProvider { anonymous, google, apple, email }

enum AdminUserKind { all, registered, guest, banned }

enum TransactionType { earn, spend }

extension LeagueTierX on LeagueTier {
  /// Localized display name. Admin UI may keep [label] (TR).
  String labelFor(String locale) => switch (locale) {
        'en' => switch (this) {
            LeagueTier.bronze => 'Bronze',
            LeagueTier.silver => 'Silver',
            LeagueTier.gold => 'Gold',
          },
        'de' => switch (this) {
            LeagueTier.bronze => 'Bronze',
            LeagueTier.silver => 'Silber',
            LeagueTier.gold => 'Gold',
          },
        'es' => switch (this) {
            LeagueTier.bronze => 'Bronce',
            LeagueTier.silver => 'Plata',
            LeagueTier.gold => 'Oro',
          },
        'fr' => switch (this) {
            LeagueTier.bronze => 'Bronze',
            LeagueTier.silver => 'Argent',
            LeagueTier.gold => 'Or',
          },
        'it' => switch (this) {
            LeagueTier.bronze => 'Bronzo',
            LeagueTier.silver => 'Argento',
            LeagueTier.gold => 'Oro',
          },
        'ru' => switch (this) {
            LeagueTier.bronze => 'Бронза',
            LeagueTier.silver => 'Серебро',
            LeagueTier.gold => 'Золото',
          },
        'nl' => switch (this) {
            LeagueTier.bronze => 'Brons',
            LeagueTier.silver => 'Zilver',
            LeagueTier.gold => 'Goud',
          },
        'pt' => switch (this) {
            LeagueTier.bronze => 'Bronze',
            LeagueTier.silver => 'Prata',
            LeagueTier.gold => 'Ouro',
          },
        'pl' => switch (this) {
            LeagueTier.bronze => 'Brąz',
            LeagueTier.silver => 'Srebro',
            LeagueTier.gold => 'Złoto',
          },
        _ => switch (this) {
            LeagueTier.bronze => 'Bronz',
            LeagueTier.silver => 'Gümüş',
            LeagueTier.gold => 'Altın',
          },
      };

  String get label => labelFor('tr');

  String get symbol => switch (this) {
        LeagueTier.bronze => '🥉',
        LeagueTier.silver => '🥈',
        LeagueTier.gold => '🥇',
      };

  int get wordLength => switch (this) {
        LeagueTier.bronze => 5,
        LeagueTier.silver => 6,
        LeagueTier.gold => 7,
      };

  int get maxAttempts => switch (this) {
        LeagueTier.bronze => 6,
        LeagueTier.silver => 6,
        LeagueTier.gold => 7,
      };

  LeagueTier? get next => switch (this) {
        LeagueTier.bronze => LeagueTier.silver,
        LeagueTier.silver => LeagueTier.gold,
        LeagueTier.gold => null,
      };

  LeagueTier? get previous => switch (this) {
        LeagueTier.bronze => null,
        LeagueTier.silver => LeagueTier.bronze,
        LeagueTier.gold => LeagueTier.silver,
      };
}
