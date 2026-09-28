import 'package:flutter/material.dart';
import 'package:kelimelig/admin/admin_app.dart';
import 'package:kelimelig/games/luno_bilgi/register_bilgi_server.dart';
import 'package:kelimelig/games/luno_fall/register_fall_server.dart';
import 'package:kelimelig/games/luno_grid/register_grid_server.dart';
import 'package:kelimelig/injection.dart';
import 'package:kelimelig/league_injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  await registerLeagueServer();
  await registerFallServer();
  await registerGridServer();
  await registerBilgiServer();
  runApp(const AdminApp());
}
