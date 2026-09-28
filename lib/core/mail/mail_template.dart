class MailTemplate {
  const MailTemplate({
    required this.subject,
    required this.htmlBody,
    required this.textBody,
  });

  final String subject;
  final String htmlBody;
  final String textBody;

  static const reset = MailTemplate(
    subject: 'Luno Bilgi şifre sıfırlama',
    htmlBody: '''
<p>Merhaba,</p>
<p>{{email}} adresi için Luno Bilgi şifre sıfırlama kodun:</p>
<p style="font-size:28px;font-weight:700;letter-spacing:4px">{{code}}</p>
<p>Kod 30 dakika geçerlidir. Bu isteği sen yapmadıysan bu e-postayı yok say.</p>
<p>Şifre, kodu girdiğin cihazdaki hesapta güncellenir.</p>
''',
    textBody: '''
{{email}} adresi için Luno Bilgi şifre sıfırlama kodun: {{code}}

Kod 30 dakika geçerlidir. Bu isteği sen yapmadıysan bu e-postayı yok say.
Şifre, kodu girdiğin cihazdaki hesapta güncellenir.
''',
  );

  MailTemplate apply({required String code, required String email}) {
    String fill(String value) => value.replaceAll('{{code}}', code).replaceAll('{{email}}', email);
    return MailTemplate(
      subject: fill(subject),
      htmlBody: fill(htmlBody),
      textBody: fill(textBody),
    );
  }

  Map<String, dynamic> toJson() => {
        'subject': subject,
        'htmlBody': htmlBody,
        'textBody': textBody,
      };

  factory MailTemplate.fromJson(Map<String, dynamic> json) {
    return MailTemplate(
      subject: '${json['subject'] ?? MailTemplate.reset.subject}',
      htmlBody: '${json['htmlBody'] ?? MailTemplate.reset.htmlBody}',
      textBody: '${json['textBody'] ?? MailTemplate.reset.textBody}',
    );
  }
}
