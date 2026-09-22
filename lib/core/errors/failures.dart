class AppFailure implements Exception {
  AppFailure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}
