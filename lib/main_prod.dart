import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scholo_admin/core/config/app_environment.dart';
import 'package:scholo_admin/core/config/firebase_options_prod.dart';
import 'package:scholo_admin/main.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(AppConfig.production()),
      ],
      child: const MyApp(),
    ),
  );
}
