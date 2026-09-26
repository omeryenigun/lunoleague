import 'package:shelf/shelf.dart';

const appAdsTxtBody =
    'google.com, pub-9773173651120365, DIRECT, f08c47fec0942fa0\n';

Response appAdsTxtPage(Request request) {
  return Response.ok(
    appAdsTxtBody,
    headers: {
      'content-type': 'text/plain; charset=utf-8',
      'cache-control': 'public, max-age=3600',
    },
  );
}
