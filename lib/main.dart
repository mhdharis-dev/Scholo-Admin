import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/config/session_manager.dart';

import 'core/config/app_environment.dart';
import 'core/config/firebase_options_prod.dart' as prod;
import 'core/config/firebase_options_test.dart' as test;
import 'routes/app_router.dart';
import 'otherplatform/platformError_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SessionManager.init();
  
  const String flavor = String.fromEnvironment('app.flavor', defaultValue: 'prod');
  
  final FirebaseOptions firebaseOptions;
  final AppConfig appConfig;
  
  if (flavor == 'test') {
    firebaseOptions = test.DefaultFirebaseOptions.currentPlatform;
    appConfig = AppConfig.testing();
  } else {
    firebaseOptions = prod.DefaultFirebaseOptions.currentPlatform;
    appConfig = AppConfig.production();
  }
  
  await Firebase.initializeApp(
    options: firebaseOptions,
  );

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(appConfig),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  static const Color primaryColor = Color(0xff1D9BF0);
  static const Color appbarColor = Colors.transparent;
  static const Color textColor = Colors.black;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);

    return MaterialApp.router(
      title: config.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: primaryColor,
        scaffoldBackgroundColor: Colors.grey.shade100,
        colorScheme: ColorScheme.light(
          primary: primaryColor,
          secondary: primaryColor,
          surface: Colors.grey.shade100,
          error: Colors.red,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: textColor,
          onError: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: appbarColor,
          foregroundColor: primaryColor,
          titleTextStyle: TextStyle(
            color: Color(0xff201e71),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.black),
          bodyMedium: TextStyle(color: Colors.black),
          titleLarge: TextStyle(color: Colors.black),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: primaryColor),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade200,
          hintStyle: const TextStyle(fontSize: 16, color: Colors.black54),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        useMaterial3: true,
      ),
      routerConfig: router,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            // Convert logical pixels to inches (approx. 160 dp = 1 inch)
            final widthInInches = constraints.maxWidth / 160;

            if (widthInInches < 6.4) {
              return const SomethingWentWrongPage();
            }

            final content = config.isProduction
                ? child!
                : Banner(
                    message: "TESTING",
                    location: BannerLocation.topEnd,
                    color: Colors.red,
                    child: child!,
                  );
            return content;
          },
        );
      },
    );
  }
}
