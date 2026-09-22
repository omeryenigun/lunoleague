import 'package:flutter/material.dart';
import 'package:kelimelig/admin/admin_app.dart';
import 'package:kelimelig/injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(const AdminApp());
}
