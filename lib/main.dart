import 'package:flutter/material.dart';
import 'package:kelimelig/core/router/app_router.dart';
import 'package:kelimelig/injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(const KelimeLigApp());
}
