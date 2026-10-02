import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_admin.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';

BilgiQuestion _question({
  required String id,
  required String categoryId,
  required String subcategory,
  required String status,
  String difficulty = 'orta',
  String text = 'Soru metni uzun',
}) {
  return BilgiQuestion(
    id: id,
    categoryId: categoryId,
    text: text,
    options: const ['bir', 'iki', 'uc', 'dort'],
    correct: 0,
    difficulty: difficulty,
    explanation: 'aciklama',
    status: status,
    tags: [subcategory],
  );
}

void main() {
  const felsefeSubs = ['Antik Yunan Felsefesi', 'Çağdaş Felsefe'];
  final questions = [
    _question(id: 'cagdas', categoryId: 'felsefe', subcategory: 'Çağdaş Felsefe', status: 'pending'),
    _question(id: 'antik', categoryId: 'felsefe', subcategory: 'Antik Yunan Felsefesi', status: 'pending', text: 'Sokrates kimdir'),
    _question(id: 'antik-onay', categoryId: 'felsefe', subcategory: 'Antik Yunan Felsefesi', status: 'approved'),
    _question(id: 'tarih', categoryId: 'tarih', subcategory: 'Osmanlı', status: 'pending'),
    _question(id: 'bosluk', categoryId: 'felsefe', subcategory: 'Antik  Yunan Felsefesi', status: 'pending'),
  ];

  test('Bekleyen lists pending questions and a category keeps every pending row in it', () {
    final pending = bilgiFilterBankQuestions(questions, status: 'pending');
    expect(pending.map((question) => question.id), ['cagdas', 'antik', 'tarih', 'bosluk']);

    final felsefe = bilgiFilterBankQuestions(
      questions,
      categoryId: 'felsefe',
      status: 'pending',
      categorySubs: felsefeSubs,
    );
    expect(felsefe.map((question) => question.id), ['cagdas', 'antik', 'bosluk']);
  });

  test('Antik Yunan excludes Çağdaş, and a subcategory outside the category does not wipe the category', () {
    final antik = bilgiFilterBankQuestions(
      questions,
      categoryId: 'felsefe',
      subcategory: 'Antik Yunan Felsefesi',
      status: 'pending',
      categorySubs: felsefeSubs,
    );
    expect(antik.map((question) => question.id), ['antik', 'bosluk']);

    final stale = bilgiFilterBankQuestions(
      questions,
      categoryId: 'felsefe',
      subcategory: 'Osmanlı',
      status: 'pending',
      categorySubs: felsefeSubs,
    );
    expect(stale.map((question) => question.id), ['cagdas', 'antik', 'bosluk']);
  });

  test('empty or short search does not hide rows, and paging uses the filtered list', () {
    final shortSearch = bilgiFilterBankQuestions(questions, status: 'pending', search: 'ab');
    expect(shortSearch.map((question) => question.id), ['cagdas', 'antik', 'tarih', 'bosluk']);

    final emptySearch = bilgiFilterBankQuestions(questions, status: 'pending', search: '  ');
    expect(emptySearch.length, 4);

    final searched = bilgiFilterBankQuestions(questions, status: 'pending', search: 'sok');
    expect(searched.map((question) => question.id), ['antik']);

    final window = bilgiBankWindow(shortSearch, 9);
    expect(window.total, 4);
    expect(window.slice.map((question) => question.id), ['cagdas', 'antik', 'tarih', 'bosluk']);
    expect(window.from, 1);
    expect(window.to, 4);

    final empty = bilgiBankWindow(bilgiFilterBankQuestions(questions, status: 'draft'), 3);
    expect(empty.total, 0);
    expect(empty.slice, isEmpty);
    expect(empty.from, 0);
    expect(empty.to, 0);
  });

  test('page size defaults to 20 and the slice follows 20, 50, 100, or 200', () {
    expect(bilgiBankPageSize, 20);
    expect(bilgiBankPageSizes, [20, 50, 100, 200]);

    final many = [
      for (var i = 0; i < 30; i++)
        _question(id: 'q$i', categoryId: 'felsefe', subcategory: 'Antik Yunan Felsefesi', status: 'pending'),
    ];
    final first = bilgiBankWindow(many, 0, pageSize: 20);
    expect(first.page, 0);
    expect(first.total, 30);
    expect(first.slice.length, 20);
    expect(first.from, 1);
    expect(first.to, 20);

    final page = bilgiBankWindow(many, 1, pageSize: 20);
    expect(page.slice.length, 10);
    expect(page.total, 30);

    for (final size in bilgiBankPageSizes) {
      expect(bilgiBankWindow(many, 0, pageSize: size).slice.length, size > 30 ? 30 : size);
      expect(bilgiBankWindow(many, 0, pageSize: size).total, 30);
    }
  });

  test('bank list correct column is the choice letter', () {
    expect(bilgiCorrectChoiceLetter(questions.first), 'A');
    expect(
      bilgiCorrectChoiceLetter(_question(
        id: 'd',
        categoryId: 'felsefe',
        subcategory: 'Antik Yunan Felsefesi',
        status: 'approved',
      ).copyWith(options: const ['alfa', 'beta', 'gama', 'delta'], correct: 2)),
      'C',
    );
    expect(
      bilgiCorrectChoiceLetter(_question(
        id: 'b',
        categoryId: 'felsefe',
        subcategory: 'Antik Yunan Felsefesi',
        status: 'approved',
      ).copyWith(correct: 1)),
      'B',
    );
    expect(
      bilgiCorrectChoiceLetter(_question(
        id: 'bos',
        categoryId: 'felsefe',
        subcategory: 'Antik Yunan Felsefesi',
        status: 'approved',
      ).copyWith(correct: 9)),
      '',
    );
  });
}
