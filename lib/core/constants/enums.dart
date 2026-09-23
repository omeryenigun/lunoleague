enum GameType { daily, endless }

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
  String labelFor(String locale) => switch (this) {
        LeagueTier.bronze => locale == 'en' ? 'Bronze' : 'Bronz',
        LeagueTier.silver => locale == 'en' ? 'Silver' : 'Gümüş',
        LeagueTier.gold => locale == 'en' ? 'Gold' : 'Altın',
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
