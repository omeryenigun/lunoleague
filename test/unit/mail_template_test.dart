import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/core/mail/mail_template.dart';

void main() {
  test('reset template fills the code and email', () {
    final filled = MailTemplate.reset.apply(code: '123456', email: 'oyuncu@example.com');
    expect(filled.subject, 'Luno Bilgi şifre sıfırlama');
    expect(filled.htmlBody, contains('123456'));
    expect(filled.htmlBody, contains('oyuncu@example.com'));
    expect(filled.textBody, contains('123456'));
    expect(filled.htmlBody.contains('{{code}}'), isFalse);
  });
}
