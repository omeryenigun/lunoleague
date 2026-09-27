import 'package:shelf/shelf.dart';

Response comingSoonPage(Request request) {
  return Response.ok(
    _html,
    headers: {
      'content-type': 'text/html; charset=utf-8',
      'cache-control': 'public, max-age=300',
    },
  );
}

const _html = '''
<!DOCTYPE html>
<html lang="tr">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Yakında</title>
  <style>
    html, body { height: 100%; margin: 0; }
    body {
      display: flex;
      align-items: center;
      justify-content: center;
      font-family: Georgia, serif;
      background: #ffffff;
      color: #1a1a1a;
    }
    p { font-size: 2rem; margin: 0; }
  </style>
</head>
<body>
  <p>Yakında</p>
</body>
</html>
''';
