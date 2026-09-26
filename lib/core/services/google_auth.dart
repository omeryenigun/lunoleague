import 'package:google_sign_in/google_sign_in.dart';
import 'package:kelimelig/core/constants/user_messages.dart';
import 'package:kelimelig/core/errors/failures.dart';

class GoogleProfile {
  const GoogleProfile({required this.id, this.email, this.displayName});

  final String id;
  final String? email;
  final String? displayName;
}

/// Real Google sign-in. Without [serverClientId] it refuses to create an account.
class GoogleAuth {
  static const serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '1092422602324-549nsqkbd6tucttgpk39nan9clkh1neg.apps.googleusercontent.com',
  );

  var _ready = false;

  Future<GoogleProfile?> signIn() async {
    if (serverClientId.isEmpty) {
      throw AppFailure(
        UserMessages.googleNotConfigured,
        code: 'NO_GOOGLE_CLIENT',
      );
    }
    final google = GoogleSignIn.instance;
    if (!_ready) {
      await google.initialize(serverClientId: serverClientId);
      _ready = true;
    }
    try {
      final account = await google.authenticate();
      final id = account.id.trim();
      if (id.isEmpty) {
        throw AppFailure(UserMessages.googleSignInFailed, code: 'NO_GOOGLE');
      }
      return GoogleProfile(
        id: id,
        email: account.email,
        displayName: account.displayName,
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      final detail = e.description?.trim();
      final message = detail == null || detail.isEmpty
          ? UserMessages.googleSignInFailed
          : '${UserMessages.googleSignInFailed} $detail';
      throw AppFailure(message, code: 'GOOGLE_FAILED');
    } on UnimplementedError {
      throw AppFailure(
        UserMessages.googleNotConfigured,
        code: 'NO_GOOGLE_CLIENT',
      );
    }
  }
}
